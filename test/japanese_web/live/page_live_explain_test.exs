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
end
