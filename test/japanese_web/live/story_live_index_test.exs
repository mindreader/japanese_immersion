defmodule JapaneseWeb.StoryLive.IndexTest do
  use JapaneseWeb.ConnCase, async: true
  use Mimic
  import Phoenix.LiveViewTest

  alias Japanese.Corpus.Story
  alias Japanese.Corpus

  setup :verify_on_exit!

  test "lists stories", %{conn: conn} do
    stories = [
      %Story{name: "story1"},
      %Story{name: "story2"}
    ]

    Mimic.stub(Corpus, :list_stories, fn -> stories end)
    {:ok, _view, html} = live(conn, ~p"/stories")
    assert html =~ "Listing Stories"
    assert html =~ "story1"
    assert html =~ "story2"
  end

  test "can delete a story from the index", %{conn: conn} do
    story = %Story{name: "story1"}
    stories = [story]
    Mimic.stub(Corpus, :list_stories, fn -> stories end)
    Mimic.stub(Story, :get_by_name, fn "story1" -> {:ok, story} end)
    Mimic.expect(Story, :delete, fn ^story -> :ok end)
    {:ok, view, html} = live(conn, ~p"/stories")
    assert html =~ "story1"

    # Click the Delete button inside the menu (tests can access hidden elements)
    view
    |> element(~s{button[data-confirm]:fl-contains('Delete')})
    |> render_click(%{"id" => "story1"})

    refute render(view) =~ "story1"
  end

  test "can edit a story from the index", %{conn: conn} do
    story = %Story{name: "story1"}
    stories = [story]
    Mimic.stub(Corpus, :list_stories, fn -> stories end)
    Mimic.stub(Story, :get_by_name, fn "story1" -> {:ok, story} end)
    {:ok, _view, html} = live(conn, ~p"/stories/story1/edit")
    assert html =~ "#story-modal"
    assert html =~ "Edit Story"
    assert html =~ "story1"
  end
end
