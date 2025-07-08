defmodule JapaneseWeb.StoryLive.ShowTest do
  use JapaneseWeb.ConnCase, async: true
  use Mimic
  import Phoenix.LiveViewTest

  alias Japanese.Corpus.Story

  setup :verify_on_exit!

  test "renders story if it exists", %{conn: conn} do
    story_name = "test_story"
    story = %Story{name: story_name}
    Mimic.expect(Story, :get_by_name, 2, fn ^story_name -> {:ok, story} end)
    {:ok, _view, html} = live(conn, ~p"/stories/#{story}")
    assert html =~ "Show Story"
    assert html =~ story.name
  end

  test "redirects with error if story does not exist", %{conn: conn} do
    story_name = "nonexistent_story"
    Mimic.expect(Story, :get_by_name, 1, fn ^story_name -> {:error, :not_found} end)
    assert {:error, {:live_redirect, %{to: "/stories"}}} = live(conn, ~p"/stories/#{story_name}")
  end

  test "can edit a story's name", %{conn: conn} do
    old_name = "test_story"
    new_name = "renamed_story"
    old_story = %Story{name: old_name}
    new_story = %Story{name: new_name}
    # get_by_name is called for old_name (show, edit, after patch) and new_name (after rename)
    Mimic.expect(Story, :get_by_name, 3, fn ^old_name -> {:ok, old_story} end)
    Mimic.expect(Story, :get_by_name, 1, fn ^new_name -> {:ok, new_story} end)
    Mimic.expect(Story, :rename, fn ^old_name, ^new_name -> {:ok, new_story} end)

    {:ok, view, _html} = live(conn, ~p"/stories/#{old_name}")
    element(view, "a", "Edit story") |> render_click()
    assert render(view) =~ "Edit Story"

    form_el = element(view, "#story-form")
    render_submit(form_el, %{story: %{name: new_name}})
    assert render(view) =~ "Story renamed successfully"
    assert_patch(view, ~p"/stories/#{new_name}")
  end
end
