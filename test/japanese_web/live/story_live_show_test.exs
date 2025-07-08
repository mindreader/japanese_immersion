defmodule JapaneseWeb.StoryLive.ShowTest do
  use JapaneseWeb.ConnCase, async: true
  use Mimic
  import Phoenix.LiveViewTest

  alias Japanese.Corpus.StorageLayer

  setup :verify_on_exit!

  setup do
    storage = StorageLayer.new()
    Mimic.stub(StorageLayer, :new, fn -> storage end)
    %{storage: storage}
  end

  test "renders story if it exists", %{conn: conn, storage: storage} do
    story_name = "test_story"
    Mimic.expect(StorageLayer, :story_exists?, 2, fn ^storage, ^story_name -> true end)
    {:ok, _view, html} = live(conn, "/stories/#{story_name}")
    assert html =~ "Show Story"
    assert html =~ story_name
  end

  test "redirects with error if story does not exist", %{conn: conn, storage: storage} do
    story_name = "nonexistent_story"
    Mimic.expect(StorageLayer, :story_exists?, fn ^storage, ^story_name -> false end)
    assert {:error, {:live_redirect, %{to: "/stories"}}} = live(conn, "/stories/#{story_name}")
  end
end
