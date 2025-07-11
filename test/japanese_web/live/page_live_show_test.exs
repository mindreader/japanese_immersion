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
