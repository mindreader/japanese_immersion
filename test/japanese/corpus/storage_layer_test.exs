defmodule Test.Japanese.Corpus.StorageLayer do
  use ExUnit.Case, async: true

  alias Japanese.Corpus.StorageLayer

  setup do
    working_directory =
      Path.join(System.tmp_dir!(), "storage_layer_test_#{System.unique_integer([:positive])}")

    story = "mystory"
    File.mkdir_p!(Path.join(working_directory, story))

    on_exit(fn -> File.rm_rf(working_directory) end)

    storage = %StorageLayer{working_directory: working_directory}
    {:ok, storage: storage, story: story}
  end

  defp write_page_files(storage, story, number) do
    jap_file = StorageLayer.page_filename(storage, story, number, :japanese)
    eng_file = StorageLayer.page_filename(storage, story, number, :translation)

    File.write!(Path.join([storage.working_directory, story, jap_file]), "japanese text")
    File.write!(Path.join([storage.working_directory, story, eng_file]), "translation")
  end

  defp files_present?(storage, story, number) do
    jap_file = StorageLayer.page_filename(storage, story, number, :japanese)
    eng_file = StorageLayer.page_filename(storage, story, number, :translation)

    File.exists?(Path.join([storage.working_directory, story, jap_file])) or
      File.exists?(Path.join([storage.working_directory, story, eng_file]))
  end

  describe "delete_page/3" do
    test "returns :ok and removes both files when both are present", %{
      storage: storage,
      story: story
    } do
      write_page_files(storage, story, 1)

      assert :ok = StorageLayer.delete_page(storage, story, 1)
      refute files_present?(storage, story, 1)
    end

    test "returns :ok when the translation file is absent but the Japanese file is present", %{
      storage: storage,
      story: story
    } do
      jap_file = StorageLayer.page_filename(storage, story, 2, :japanese)
      File.write!(Path.join([storage.working_directory, story, jap_file]), "japanese text")

      assert :ok = StorageLayer.delete_page(storage, story, 2)
      refute files_present?(storage, story, 2)
    end

    test "returns :ok when the Japanese file is absent but the translation file is present", %{
      storage: storage,
      story: story
    } do
      eng_file = StorageLayer.page_filename(storage, story, 3, :translation)
      File.write!(Path.join([storage.working_directory, story, eng_file]), "translation")

      assert :ok = StorageLayer.delete_page(storage, story, 3)
      refute files_present?(storage, story, 3)
    end

    test "returns :ok when neither file exists (idempotent delete)", %{
      storage: storage,
      story: story
    } do
      assert :ok = StorageLayer.delete_page(storage, story, 4)
    end

    test "propagates a genuine filesystem error instead of treating it as success", %{
      storage: storage,
      story: story
    } do
      jap_file = StorageLayer.page_filename(storage, story, 5, :japanese)
      jap_path = Path.join([storage.working_directory, story, jap_file])
      File.write!(jap_path, "japanese text")

      # Make the story directory unwritable so File.rm/1 fails with :eacces
      # instead of :enoent.
      story_dir = Path.join(storage.working_directory, story)
      File.chmod!(story_dir, 0o555)

      on_exit(fn -> File.chmod(story_dir, 0o755) end)

      assert {:error, reason} = StorageLayer.delete_page(storage, story, 5)
      assert reason in [:eacces, :eperm]
    end
  end
end
