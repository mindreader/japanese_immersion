defmodule JapaneseWeb.DrillLive.ExplainTest do
  # Uses Mimic in :global mode so the stubbed Japanese.Translation call can be
  # observed from the supervised Task spawned by start_explain, not just the
  # test process itself — global mode tests must not run async.
  use JapaneseWeb.ConnCase, async: false
  use Mimic
  import Phoenix.LiveViewTest

  alias Japanese.Translation

  setup :set_mimic_global
  setup :verify_on_exit!

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

  test "start_explain shows the explanation once the task succeeds", %{conn: conn} do
    Mimic.stub(Translation, :explain_form, fn _ctx -> "**short** note" end)

    {:ok, view, _html} = live(conn, ~p"/drill")
    render_click(view, "reveal", %{})
    render_click(view, "start_explain", %{})

    eventually(fn -> render(view) =~ "note" end)
    refute render(view) =~ "Generating explanation..."
  end

  test "start_explain surfaces an error message when the LLM call fails", %{conn: conn} do
    Mimic.stub(Translation, :explain_form, fn _ctx -> {:error, :timeout} end)

    {:ok, view, _html} = live(conn, ~p"/drill")
    render_click(view, "reveal", %{})
    render_click(view, "start_explain", %{})

    eventually(fn -> render(view) =~ "Failed to generate explanation" end)
  end

  @tag capture_log: true
  test "a crashed explain task clears the spinner and surfaces an error", %{conn: conn} do
    Mimic.stub(Translation, :explain_form, fn _ctx -> raise "boom" end)

    {:ok, view, _html} = live(conn, ~p"/drill")
    render_click(view, "reveal", %{})
    render_click(view, "start_explain", %{})

    eventually(fn -> render(view) =~ "Failed to generate explanation" end)
    refute render(view) =~ "Generating explanation..."
  end

  test "cancel_explain terminates the task instead of leaving the spinner hanging", %{conn: conn} do
    test_pid = self()

    Mimic.stub(Translation, :explain_form, fn _ctx ->
      send(test_pid, :explain_started)
      Process.sleep(5_000)
      "should never get here"
    end)

    {:ok, view, _html} = live(conn, ~p"/drill")
    render_click(view, "reveal", %{})
    render_click(view, "start_explain", %{})
    assert_receive :explain_started, 1_000

    render_click(view, "cancel_explain", %{})

    refute render(view) =~ "Generating explanation..."
    Process.sleep(50)
    refute render(view) =~ "should never get here"
  end
end
