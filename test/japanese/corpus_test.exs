defmodule Test.Japanese.Corpus do
  use ExUnit.Case, async: true
  use Mimic

  alias Japanese.Corpus.Story
  alias Japanese.Corpus.Page
  alias Japanese.Corpus.StorageLayer
  alias Japanese.Corpus

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

      assert [%{name: "story1"}, %{name: "story2"}] = Corpus.list_stories()
    end

    test "returns an empty list if StorageLayer returns an error", %{storage: storage} do
      expect(StorageLayer, :list_stories, 1, fn ^storage -> {:error, :not_found} end)

      assert [] = Corpus.list_stories()
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
      expected_page = %Page{number: 3, story: "mystory"}

      expect(StorageLayer, :create_japanese_page, 1, fn ^storage, "mystory", "new content" ->
        {:ok, expected_page}
      end)

      assert {:ok, ^expected_page} = Story.add_japanese_page(story, "new content")
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

  describe "Page.write_english_translation/2" do
    setup :verify_on_exit!

    test "writes a translation file for a page (translation file: <number>tr.yaml)", %{
      storage: storage
    } do
      page = %Page{number: 5, story: "mystory"}

      japanese_text = "そして私は預言者と共に王都に向かうことになったのだ。"

      interleaved_translation = """
      そして私は預言者と共に王都に向かうことになったのだ。

      And so I came to head to the royal capital together with the prophet.

      !CONTINUED!
      """

      expected_json =
        Japanese.Translation.Json.format_to_translation_json(interleaved_translation)

      stub(Japanese.Translation, :ja_to_en, fn ^japanese_text, interleaved: true ->
        %Japanese.Translation{text: interleaved_translation}
      end)

      expect(StorageLayer, :write_english_translation, 1, fn ^storage,
                                                             "mystory",
                                                             5,
                                                             ^expected_json ->
        {:ok, :written}
      end)

      assert :ok = Page.translate_page(page, japanese_text)
    end
  end

  describe "Page.delete/1" do
    setup :verify_on_exit!

    test "deletes both Japanese and translation files for a page", %{storage: storage} do
      page = %Page{number: 7, story: "mystory"}

      expect(StorageLayer, :delete_page, 1, fn ^storage, "mystory", 7 -> :ok end)

      assert :ok = Page.delete(page)
    end

    test "returns error if Japanese file does not exist", %{storage: storage} do
      page = %Page{number: 8, story: "mystory"}

      expect(StorageLayer, :delete_page, 1, fn ^storage, "mystory", 8 -> {:error, :enoent} end)

      assert {:error, :enoent} = Page.delete(page)
    end
  end

  describe "Story.delete/1" do
    setup :verify_on_exit!

    test "deletes a story and all its files", %{storage: storage} do
      story = %Story{name: "mystory"}
      expect(StorageLayer, :delete_story, 1, fn ^storage, "mystory" -> :ok end)
      assert :ok = Story.delete(story)
    end

    test "returns error if deletion fails", %{storage: storage} do
      story = %Story{name: "mystory"}
      expect(StorageLayer, :delete_story, 1, fn ^storage, "mystory" -> {:error, :some_reason} end)
      assert {:error, :some_reason} = Story.delete(story)
    end
  end

  describe "Page.get_japanese_text/1" do
    setup :verify_on_exit!

    test "delegates to StorageLayer and returns the Japanese text", %{storage: storage} do
      page = %Page{number: 2, story: "mystory"}
      expected_text = "これは日本語のテキストです。"

      expect(StorageLayer, :get_japanese_text, 1, fn ^storage, "mystory", 2 ->
        {:ok, expected_text}
      end)

      assert {:ok, ^expected_text} = Page.get_japanese_text(page)
    end
  end
end
