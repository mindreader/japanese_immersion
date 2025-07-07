defmodule Japanese.CorpusTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Japanese.Corpus
  alias Japanese.Corpus.StorageLayer

  describe "list_stories/1" do
    setup do
      stub(StorageLayer, :list_stories, fn %StorageLayer{} -> {:ok, []} end)
      :ok
    end

    setup :verify_on_exit!

    test "returns a list of stories from the StorageLayer abstraction" do
      fs_result = {:ok, ["story1", "story2"]}

      expect(StorageLayer, :list_stories, 1, fn %StorageLayer{working_directory: "txt"} ->
        fs_result
      end)

      assert [%{name: "story1"}, %{name: "story2"}] = Corpus.list_stories("txt")
    end

    test "returns an empty list if StorageLayer returns an error" do
      assert Corpus.list_stories("txt") == []
    end
  end
end
