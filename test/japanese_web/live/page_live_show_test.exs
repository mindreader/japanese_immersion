defmodule JapaneseWeb.PageLive.ShowTest do
  use JapaneseWeb.ConnCase, async: true
  use Mimic
  import Phoenix.LiveViewTest

  alias Japanese.Corpus.Story
  alias Japanese.Corpus.Page

  setup :verify_on_exit!

  test "renders page with translation", %{conn: conn} do
    story = %Story{name: "test_story"}
    page = %Page{number: 1, story: story.name}
    translation = %{translation: [%{japanese: "こんにちは", english: "Hello!"}]}
    Mimic.stub(Story, :get_by_name, fn "test_story" -> {:ok, story} end)
    Mimic.stub(Story, :get_page, fn ^story, 1 -> {:ok, page} end)
    Mimic.expect(Page, :get_translation, 2, fn ^page -> {:ok, translation} end)
    {:ok, _view, html} = live(conn, ~p"/stories/#{story.name}/#{page.number}")
    assert html =~ "Page 1 of test_story"
    assert html =~ "こんにちは"
    assert html =~ "Hello!"
  end

  test "has the Recent lookups button and its client-side dialog", %{conn: conn} do
    story = %Story{name: "test_story"}
    page = %Page{number: 1, story: story.name}
    translation = %{translation: [%{japanese: "こんにちは", english: "Hello!"}]}
    Mimic.stub(Story, :get_by_name, fn "test_story" -> {:ok, story} end)
    Mimic.stub(Story, :get_page, fn ^story, 1 -> {:ok, page} end)
    Mimic.stub(Page, :get_translation, fn ^page -> {:ok, translation} end)
    {:ok, view, _html} = live(conn, ~p"/stories/#{story.name}/#{page.number}")

    assert has_element?(view, "#recent-words-open", "Recent")
    # Filled in by the RecentWords JS hook; LiveView must leave it alone.
    assert has_element?(view, "#recent-words-modal[phx-hook=RecentWords][phx-update=ignore]")
    # Outside the story's TextSelection hook, so selecting a word in the
    # dialog isn't treated as a selection in the story.
    refute has_element?(view, "#story-container #recent-words-modal")
  end

  test "mounts the keyboard shortcuts and labels the buttons", %{conn: conn} do
    story = %Story{name: "test_story"}
    page = %Page{number: 1, story: story.name}
    translation = %{translation: [%{japanese: "こんにちは", english: "Hello!"}]}
    Mimic.stub(Story, :get_by_name, fn "test_story" -> {:ok, story} end)
    Mimic.stub(Story, :get_page, fn ^story, 1 -> {:ok, page} end)
    Mimic.stub(Page, :get_translation, fn ^page -> {:ok, translation} end)
    {:ok, view, _html} = live(conn, ~p"/stories/#{story.name}/#{page.number}")

    assert has_element?(
             view,
             "#story-shortcuts[phx-hook=StoryShortcuts][data-root='#story-container']" <>
               "[data-scroll='#story-scroll-container']"
           )

    assert has_element?(view, "button[aria-keyshortcuts=E]", "Toggle English")

    # JPDB only appears once Japanese text is selected.
    refute has_element?(view, "#jpdb-button")
    render_hook(view, "text_selected", %{"text" => "こんにちは"})
    assert has_element?(view, "#jpdb-button[aria-keyshortcuts=D]", "JPDB")
  end

  test "updates when translation is finished", %{conn: conn} do
    story = %Story{name: "test_story"}
    page = %Page{number: 1, story: story.name}
    initial_translation = %{translation: [%{japanese: "こんにちは", english: nil}]}
    updated_translation = %{translation: [%{japanese: "こんにちは", english: "Hello, world!"}]}
    Mimic.stub(Story, :get_by_name, fn "test_story" -> {:ok, story} end)
    Mimic.stub(Story, :get_page, fn ^story, 1 -> {:ok, page} end)
    Mimic.expect(Page, :get_translation, 2, fn ^page -> {:ok, initial_translation} end)
    {:ok, view, html} = live(conn, ~p"/stories/#{story.name}/#{page.number}")
    assert html =~ "こんにちは"

    # Now expect updated translation for the next call
    Mimic.expect(Page, :get_translation, 1, fn ^page -> {:ok, updated_translation} end)
    send(view.pid, {:translation_finished, %{story: story.name, page: 1}})
    html = render(view)
    assert html =~ "こんにちは"
    assert html =~ "Hello, world!"
  end
end
