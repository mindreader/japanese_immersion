defmodule JapaneseWeb.StoryLive.ShowTest do
  use JapaneseWeb.ConnCase, async: true
  use Mimic
  import Phoenix.LiveViewTest

  alias Japanese.Corpus.Story
  alias Japanese.Corpus.StorageLayer

  setup :verify_on_exit!

  setup do
    storage = StorageLayer.new()
    Mimic.stub(StorageLayer, :new, fn -> storage end)
    %{storage: storage}
  end

  test "renders story if it exists", %{conn: conn, storage: storage} do
    Mimic.expect(StorageLayer, :story_exists?, 2, fn ^storage, "test_story" -> true end)
    {:ok, _view, html} = live(conn, "/stories/test_story")
    assert html =~ "Show Story"
    assert html =~ "test_story"
  end

  test "redirects with error if story does not exist", %{conn: conn, storage: storage} do
    Mimic.expect(StorageLayer, :story_exists?, fn ^storage, "nonexistent_story" -> false end)
    assert {:error, {:live_redirect, %{to: "/stories"}}} = live(conn, "/stories/nonexistent_story")
  end
end
