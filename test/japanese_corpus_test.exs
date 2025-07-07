defmodule Japanese.CorpusTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Japanese.Corpus.Story
  alias Japanese.Corpus.Page
  alias Japanese.Corpus.StorageLayer

  setup do
    storage = StorageLayer.new()
    {:ok, storage: storage}
  end

  describe "list_stories/1" do
    setup %{storage: storage} do
      stub(StorageLayer, :list_stories, fn ^storage -> {:ok, []} end)
      :ok
    end

    setup :verify_on_exit!

    test "returns a list of stories from the StorageLayer abstraction", %{storage: storage} do
      fs_result = {:ok, ["story1", "story2"]}

      expect(StorageLayer, :list_stories, 1, fn ^storage -> fs_result end)

      assert [%{name: "story1"}, %{name: "story2"}] =
               StorageLayer.list_stories(storage)
               |> (case do
                     {:ok, entries} -> Enum.map(entries, fn name -> %Story{name: name} end)
                     _ -> []
                   end)
    end

    test "returns an empty list if StorageLayer returns an error", %{storage: storage} do
      assert StorageLayer.list_stories(storage) == {:ok, []}
    end
  end

  describe "Story.list_pages/2" do
    setup :verify_on_exit!

    test "returns a list of Page structs for a story", %{storage: storage} do
      story = %Story{name: "mystory"}

      fake_pairs = [
        %{number: 1},
        %{number: 2}
      ]

      expect(StorageLayer, :pair_files, 1, fn ^storage, "mystory" -> {:ok, fake_pairs} end)

      pages = Story.list_pages(story)

      assert [
               %Page{number: 1, story: "mystory"},
               %Page{number: 2, story: "mystory"}
             ] = pages
    end
  end

  describe "Story.add_japanese_page/3" do
    setup :verify_on_exit!

    test "creates a new Japanese page with the next available number", %{storage: storage} do
      story = %Story{name: "mystory"}
      expect(StorageLayer, :next_page_filename, 1, fn ^storage, "mystory" -> "3j.md" end)

      expect(StorageLayer, :write_page, 1, fn ^storage, "mystory", "3j.md", "new content" ->
        :ok
      end)

      expect(StorageLayer, :extract_page_number, 1, fn "3j.md" -> 3 end)

      assert {:ok, %Page{number: 3, story: "mystory"}} =
               Story.add_japanese_page(story, "new content")
    end
  end

  describe "Story.create/1" do
    setup :verify_on_exit!

    test "creates a new story and returns the struct", %{storage: storage} do
      expect(StorageLayer, :create_story, 1, fn ^storage, "newstory" -> :ok end)
      assert {:ok, %Story{name: "newstory"}} = Story.create("newstory")
    end

    test "returns error if creation fails", %{storage: storage} do
      expect(StorageLayer, :create_story, 1, fn ^storage, "failstory" -> {:error, :eacces} end)
      assert {:error, :eacces} = Story.create("failstory")
    end
  end

  describe "Page.translate/2" do
    setup :verify_on_exit!

    test "writes an English translation for a page", %{storage: storage} do
      page = %Page{number: 5, story: "mystory"}
      english = "This is the English translation."

      expect(StorageLayer, :write_translation, 1, fn ^storage, "mystory", 5, ^english ->
        {:ok, :written}
      end)

      assert {:ok, :written} = Page.translate(page, english)
    end
  end
end
