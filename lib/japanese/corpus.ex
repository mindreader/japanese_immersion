defmodule Japanese.Corpus do
  @moduledoc """
  Provides primitive functions for accessing and managing a Japanese-English text corpus.

  Features:
  - List stories (subdirectories) in the corpus
  - List Japanese files in a story
  - Pair Japanese files with English files, reporting missing translations
  - Read and edit file contents
  """

  alias Japanese.Corpus.Story
  alias Japanese.Corpus.StorageLayer

  @doc """
  Lists all stories (subdirectories) in the given root directory (default: "txt/").
  Uses the StorageLayer abstraction for access.
  Returns a list of %Japanese.Corpus.Story{} structs with only the name field set.
  """
  @spec list_stories(String.t()) :: [Story.t()]
  def list_stories(root_dir \\ "txt") do
    fs = %StorageLayer{working_directory: root_dir}

    case StorageLayer.list_stories(fs) do
      {:ok, entries} ->
        Enum.map(entries, fn name -> %Japanese.Corpus.Story{name: name} end)

      _ ->
        []
    end
  end

  @doc """
  Lists all files in the given directory that end with the specified extension.
  Returns a list of file names as strings.
  """
  # TODO this needs to move to Japanese.Corpus.StorageLayer
  @spec list_files_with_extension(String.t(), String.t()) :: [String.t()]
  def list_files_with_extension(dir, ext) do
    with {:ok, entries} <- File.ls(dir) do
      entries
      |> Enum.filter(fn entry ->
        String.ends_with?(entry, ext) &&
          File.regular?(Path.join(dir, entry))
      end)
    else
      _ -> []
    end
  end
end
