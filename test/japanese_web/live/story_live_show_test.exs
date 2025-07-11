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
    # get_by_name is called for old_name (once for initial load, once for live view)
    Mimic.expect(Story, :get_by_name, 2, fn ^old_name -> {:ok, old_story} end)
    {:ok, view, _html} = live(conn, ~p"/stories/#{old_name}")

    # When the edit modal is opened, get_by_name is called again for old_name
    Mimic.expect(Story, :get_by_name, 1, fn ^old_name -> {:ok, old_story} end)
    view |> element("a", "Edit story") |> render_click()

    # Actual rename happens, check that new name is not taken, then get_by_name is called for new_name upon rerender
    Mimic.expect(Story, :rename, 1, fn ^old_name, ^new_name -> {:ok, new_story} end)
    Mimic.expect(Story, :get_by_name, 2, fn ^new_name -> {:ok, new_story} end)

    form = form(view, "#story-form", name: new_name)
    _html = render_submit(form)

    assert has_element?(view, "form#story-form") == false
    assert render(view) =~ "Story renamed successfully"
    assert render(view) =~ new_name
  end

  test "can edit a page", %{conn: conn} do
    story_name = "test_story"
    story = %Story{name: story_name}
    page = %Japanese.Corpus.Page{number: 1, story: story_name, translated?: false}
    old_text = "old text"
    new_text = "new text"
    # Initial load: story exists, has one page, static render then live view render
    Mimic.expect(Story, :get_by_name, 2, fn ^story_name -> {:ok, story} end)
    Mimic.expect(Story, :list_pages, 2, fn ^story -> [page] end)
    {:ok, view, html} = live(conn, ~p"/stories/#{story}")
    assert html =~ "Page #1"

    # Mock get_japanese_text for edit modal
    Mimic.expect(Japanese.Corpus.Page, :get_japanese_text, 1, fn ^page -> {:ok, old_text} end)
    # Open edit modal
    Mimic.expect(Story, :get_by_name, 1, fn ^story_name -> {:ok, story} end)
    Mimic.expect(Story, :list_pages, 1, fn ^story -> [page] end)

    view |> element(~s{button[phx-click="edit_page"][phx-value-number="1"]}) |> render_click()
    assert render(view) =~ old_text

    # Mock update and translation
    Mimic.expect(Japanese.Corpus.Page, :update_japanese_text, 1, fn ^page, ^new_text -> :ok end)
    Mimic.expect(Japanese.Translation.Service, :translate_page, 1, fn ^page -> :ok end)

    # After update, list_pages returns updated page
    updated_page = %Japanese.Corpus.Page{page | translated?: false}
    Mimic.expect(Story, :list_pages, 1, fn ^story -> [updated_page] end)

    form = form(view, "#edit-page-modal form", japanese_text: new_text)
    render_submit(form)
    # After submit, the edit modal should be closed
    refute render(view) =~ "#edit-page-modal"
  end

  test "can delete a page", %{conn: conn} do
    story_name = "test_story"
    story = %Story{name: story_name}
    page = %Japanese.Corpus.Page{number: 1, story: story_name, translated?: false}
    # Initial load: story exists, has one page
    Mimic.expect(Story, :get_by_name, 2, fn ^story_name -> {:ok, story} end)
    Mimic.expect(Story, :list_pages, 2, fn ^story -> [page] end)
    {:ok, view, html} = live(conn, ~p"/stories/#{story}")
    assert html =~ "Page #1"
    # Mock delete and list_pages after deletion
    Mimic.expect(Japanese.Corpus.Page, :delete, 1, fn ^page -> :ok end)
    Mimic.expect(Story, :list_pages, 1, fn ^story -> [] end)
    view |> element("button", "Delete") |> render_click(%{"number" => "1"})
    assert render(view) =~ "Pages"
    refute render(view) =~ "Page #1"
  end

  test "shows edit story modal when Edit story is clicked", %{conn: conn} do
    story_name = "test_story"
    story = %Story{name: story_name}
    Mimic.expect(Story, :get_by_name, 2, fn ^story_name -> {:ok, story} end)
    {:ok, view, _html} = live(conn, ~p"/stories/#{story}")
    Mimic.expect(Story, :get_by_name, 1, fn ^story_name -> {:ok, story} end)
    view |> element("a", "Edit story") |> render_click()
    assert render(view) =~ "#story-modal"
  end

  test "shows add page modal when Add Page is clicked", %{conn: conn} do
    story_name = "test_story"
    story = %Story{name: story_name}
    Mimic.expect(Story, :get_by_name, 2, fn ^story_name -> {:ok, story} end)
    {:ok, view, _html} = live(conn, ~p"/stories/#{story}")

    Mimic.expect(Story, :get_by_name, 1, fn ^story_name -> {:ok, story} end)
    # Simulate navigation to the add page route
    render_patch(view, ~p"/stories/#{story}/add")
    assert render(view) =~ "#new-page-modal"
  end

  test "shows edit page modal when Edit is clicked for a page", %{conn: conn} do
    story_name = "test_story"
    story = %Story{name: story_name}
    page = %Japanese.Corpus.Page{number: 1, story: story_name, translated?: false}
    old_text = "old text"
    Mimic.expect(Story, :get_by_name, 2, fn ^story_name -> {:ok, story} end)
    Mimic.expect(Story, :list_pages, 2, fn ^story -> [page] end)
    {:ok, view, _html} = live(conn, ~p"/stories/#{story}")
    Mimic.expect(Japanese.Corpus.Page, :get_japanese_text, 1, fn ^page -> {:ok, old_text} end)
    view |> element(~s{button[phx-click="edit_page"][phx-value-number="1"]}) |> render_click()
    assert render(view) =~ "#edit-page-modal"
  end
end
