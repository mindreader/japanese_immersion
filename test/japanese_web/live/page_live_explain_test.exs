defmodule JapaneseWeb.PageLive.ExplainTest do
  # Uses Mimic in :global mode so the stubbed Japanese.Translation call can be
  # observed from the supervised Task spawned by start_explain, not just the
  # test process itself — global mode tests must not run async.
  use JapaneseWeb.ConnCase, async: false
  use Mimic
  import Phoenix.LiveViewTest

  alias Japanese.Corpus.Page
  alias Japanese.Corpus.Story
  alias Japanese.Translation

  setup :set_mimic_global
  setup :verify_on_exit!

  setup %{conn: conn} do
    story = %Story{name: "test_story"}
    page = %Page{number: 1, story: story.name}

    Mimic.stub(Story, :get_by_name, fn "test_story" -> {:ok, story} end)
    Mimic.stub(Story, :get_page, fn ^story, 1 -> {:ok, page} end)
    Mimic.stub(Page, :get_translation, fn ^page -> {:ok, %{translation: []}} end)

    {:ok, view, _html} = live(conn, ~p"/stories/#{story.name}/#{page.number}")

    %{view: view, story: story, page: page}
  end

  defp eventually(fun, retries \\ 100) do
    if fun.() do
      :ok
    else
      if retries <= 0 do
        flunk("condition was never satisfied")
      else
        Process.sleep(10)
        eventually(fun, retries - 1)
      end
    end
  end

  test "start_explain shows the explanation once the task succeeds", %{view: view} do
    Mimic.stub(Translation, :explain_text, fn "hello" -> "**hi** there" end)

    render_click(view, "start_explain", %{"text" => "hello"})

    eventually(fn -> render(view) =~ "there" end)
    refute render(view) =~ "Cancel..."
  end

  test "start_explain surfaces an error message when the LLM call fails", %{view: view} do
    Mimic.stub(Translation, :explain_text, fn "hello" -> {:error, :timeout} end)

    render_click(view, "start_explain", %{"text" => "hello"})

    eventually(fn -> render(view) =~ "Failed to generate explanation" end)
  end

  @tag capture_log: true
  test "a crashed explain task clears the spinner and surfaces an error", %{view: view} do
    Mimic.stub(Translation, :explain_text, fn "hello" -> raise "boom" end)

    render_click(view, "start_explain", %{"text" => "hello"})

    eventually(fn -> render(view) =~ "Failed to generate explanation" end)
    refute render(view) =~ "Cancel..."
  end

  test "cancel_explain terminates the task instead of leaving the spinner hanging", %{
    view: view
  } do
    test_pid = self()

    Mimic.stub(Translation, :explain_text, fn "hello" ->
      send(test_pid, :explain_started)
      Process.sleep(5_000)
      "should never get here"
    end)

    render_click(view, "start_explain", %{"text" => "hello"})
    assert_receive :explain_started, 1_000

    render_click(view, "cancel_explain", %{})

    refute render(view) =~ "Cancel..."
    # Give the (now-terminated) task a moment to try to reply; it must not.
    Process.sleep(50)
    refute render(view) =~ "should never get here"
  end

  describe "follow-up questions" do
    setup %{view: view} do
      Mimic.stub(Translation, :explain_text, fn "猫" -> "**猫** (ねこ) = cat" end)
      render_click(view, "start_explain", %{"text" => "猫"})
      eventually(fn -> render(view) =~ "Ask a follow-up" end)
      :ok
    end

    test "an answer appears under the explanation, and the next question gets the thread",
         %{view: view} do
      test_pid = self()

      Mimic.stub(Translation, :explain_followup, fn passage, explanation, turns, question ->
        send(test_pid, {:followup, passage, explanation, turns, question})
        "Answer to: " <> question
      end)

      view |> form("#followup-form", %{"question" => "  Why ねこ?  "}) |> render_submit()

      assert_receive {:followup, "猫", "**猫** (ねこ) = cat", [], "Why ねこ?"}, 1_000
      eventually(fn -> render(view) =~ "Answer to: Why ねこ?" end)

      view |> form("#followup-form", %{"question" => "And 猫舌?"}) |> render_submit()

      assert_receive {:followup, "猫", _, [{"Why ねこ?", "Answer to: Why ねこ?"}], "And 猫舌?"},
                     1_000

      eventually(fn -> render(view) =~ "Answer to: And 猫舌?" end)
      assert render(view) =~ "<strong>猫</strong>"
    end

    test "the dialog opens focused on its heading, not the box", %{view: view} do
      html = render(view)

      # JS.focus_first takes the first tabbable element: the heading has to
      # come before the input, or phones open their keyboard on open.
      {heading, _} = :binary.match(html, ~s(id="explanation-heading"))
      {input, _} = :binary.match(html, ~s(name="question"))
      assert heading < input
      assert has_element?(view, ~s(#explanation-heading[tabindex="0"]))
      assert has_element?(view, ~s(input[name="question"][phx-hook="FollowupFocus"]))
    end

    test "a blank question sends nothing", %{view: view} do
      Mimic.reject(&Translation.explain_followup/4)

      view |> form("#followup-form", %{"question" => "   "}) |> render_submit()

      refute render(view) =~ "Thinking"
    end

    test "a failed follow-up shows an error and isn't sent back next time", %{view: view} do
      test_pid = self()

      Mimic.stub(Translation, :explain_followup, fn _p, _e, turns, question ->
        send(test_pid, {:turns, turns})
        if question == "first", do: {:error, :timeout}, else: "fine"
      end)

      view |> form("#followup-form", %{"question" => "first"}) |> render_submit()
      eventually(fn -> render(view) =~ "Failed to generate explanation" end)

      view |> form("#followup-form", %{"question" => "second"}) |> render_submit()
      eventually(fn -> render(view) =~ "fine" end)

      assert_receive {:turns, []}
      assert_receive {:turns, []}
    end

    test "closing the explanation drops the thread and stops a pending answer", %{view: view} do
      test_pid = self()

      Mimic.stub(Translation, :explain_followup, fn _p, _e, _t, _q ->
        send(test_pid, :followup_started)
        Process.sleep(5_000)
        "should never get here"
      end)

      view |> form("#followup-form", %{"question" => "slow"}) |> render_submit()
      assert_receive :followup_started, 1_000
      assert render(view) =~ "Thinking"

      render_click(view, "close_explanation_modal", %{})
      Process.sleep(50)

      html = render(view)
      refute html =~ "slow"
      refute html =~ "should never get here"
      refute html =~ "Ask a follow-up"
    end
  end

  test "no follow-up box when the explanation itself failed", %{view: view} do
    Mimic.stub(Translation, :explain_text, fn "hello" -> {:error, :timeout} end)

    render_click(view, "start_explain", %{"text" => "hello"})

    eventually(fn -> render(view) =~ "Failed to generate explanation" end)
    refute render(view) =~ "Ask a follow-up"
  end
end
