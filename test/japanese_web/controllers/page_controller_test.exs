defmodule JapaneseWeb.PageControllerTest do
  use JapaneseWeb.ConnCase, async: true
  use Mimic

  alias Japanese.Corpus.{Story, Page}

  setup :verify_on_exit!

  test "serves the original japanese page", %{conn: conn} do
    story_name = "test_story"
    page_number = 1
    page = %Page{number: page_number, story: story_name, translated?: false}
    japanese_text = "これは日本語のテキストです。"

    Mimic.expect(Story, :get_by_name, 1, fn ^story_name -> {:ok, %Story{name: story_name}} end)
    Mimic.expect(Story, :get_page, 1, fn %Story{name: ^story_name}, ^page_number -> {:ok, page} end)
    Mimic.expect(Page, :get_japanese_text, 1, fn ^page -> {:ok, japanese_text} end)

    conn = get(conn, "/stories/#{story_name}/#{page_number}/japanese")
    assert html_response(conn, 200) =~ japanese_text
  end

  test "returns 404 if story or page is not found", %{conn: conn} do
    story_name = "missing_story"
    page_number = 1

    # Simulate story not found
    Mimic.expect(Japanese.Corpus.Story, :get_by_name, 1, fn ^story_name -> {:error, :not_found} end)

    conn = get(conn, "/stories/#{story_name}/#{page_number}/japanese")
    assert response(conn, 404) =~ "Story or page not found."
  end

  test "returns 404 if page number is invalid", %{conn: conn} do
    story_name = "test_story"
    invalid_page = "notanumber"

    # get_by_name should succeed, but page number is invalid
    Mimic.expect(Japanese.Corpus.Story, :get_by_name, 1, fn ^story_name -> {:ok, %Story{name: story_name}} end)

    conn = get(conn, "/stories/#{story_name}/#{invalid_page}/japanese")
    assert response(conn, 404) =~ "Invalid page number."
  end
end
