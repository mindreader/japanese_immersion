defmodule JapaneseWeb.PageLive.ReadingTest do
  # Uses Mimic in :global mode so the stubbed Japanese.Translation call can be
  # observed from the supervised Task spawned by start_reading, not just the
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

  test "start_reading shows the reading once the task succeeds", %{view: view} do
    Mimic.stub(Translation, :reading_for, fn "勉強した", "彼は勉強した。" ->
      {:ok, "べんきょうした"}
    end)

    render_click(view, "start_reading", %{"text" => "勉強した", "context" => "彼は勉強した。"})

    eventually(fn -> render(view) =~ "べんきょうした" end)
    refute render(view) =~ "explanation-modal"
  end

  test "the containing sentence is actually sent to the model, not just the selection", %{
    view: view
  } do
    test_pid = self()
    sentence = "彼は昨日日本語を勉強した。"

    Mimic.stub(Translation, :reading_for, fn selection, context ->
      send(test_pid, {:reading_for_called, selection, context})
      {:ok, "べんきょうした"}
    end)

    render_click(view, "start_reading", %{"text" => "勉強した", "context" => sentence})

    eventually(fn -> render(view) =~ "べんきょうした" end)

    assert_received {:reading_for_called, "勉強した", ^sentence}
  end

  test "start_reading surfaces an 'unknown' result as a neutral note, not an error", %{
    view: view
  } do
    Mimic.stub(Translation, :reading_for, fn _selection, _context -> :unknown end)

    render_click(view, "start_reading", %{"text" => "名前", "context" => "名前は分からない。"})

    eventually(fn -> render(view) =~ "No confident reading" end)
    refute render(view) =~ "Failed"
  end

  test "start_reading surfaces an error message when the LLM call fails", %{view: view} do
    Mimic.stub(Translation, :reading_for, fn _selection, _context -> {:error, :timeout} end)

    render_click(view, "start_reading", %{"text" => "猫", "context" => "猫がいる。"})

    eventually(fn -> render(view) =~ "Could not look up reading" end)
  end

  @tag capture_log: true
  test "a crashed reading task clears the spinner and surfaces an error", %{view: view} do
    Mimic.stub(Translation, :reading_for, fn _selection, _context -> raise "boom" end)

    render_click(view, "start_reading", %{"text" => "猫", "context" => "猫がいる。"})

    eventually(fn -> render(view) =~ "Failed to look up reading" end)
    refute render(view) =~ "Cancel..."
  end

  test "cancel_reading terminates the task instead of leaving the spinner hanging", %{
    view: view
  } do
    test_pid = self()

    Mimic.stub(Translation, :reading_for, fn _selection, _context ->
      send(test_pid, :reading_started)
      Process.sleep(5_000)
      {:ok, "should never get here"}
    end)

    render_click(view, "start_reading", %{"text" => "猫", "context" => "猫がいる。"})
    assert_receive :reading_started, 1_000

    render_click(view, "cancel_reading", %{})

    refute render(view) =~ "Cancel..."
    # Give the (now-terminated) task a moment to try to reply; it must not.
    Process.sleep(50)
    refute render(view) =~ "should never get here"
  end

  test "close_reading dismisses the popover", %{view: view} do
    Mimic.stub(Translation, :reading_for, fn _selection, _context -> {:ok, "ねこ"} end)

    render_click(view, "start_reading", %{"text" => "猫", "context" => "猫がいる。"})
    eventually(fn -> render(view) =~ "ねこ" end)

    render_click(view, "close_reading", %{})

    refute render(view) =~ "ねこ"
  end
end
