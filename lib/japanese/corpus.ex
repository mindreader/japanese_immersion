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
  Lists all stories (subdirectories) in the corpus.
  Uses the StorageLayer abstraction for access.
  Returns a list of %Japanese.Corpus.Story{} structs with only the name field set.
  """
  @spec list_stories() :: [Story.t()]
  def list_stories() do
    StorageLayer.new()
    |> StorageLayer.list_stories()
    |> case do
      {:ok, entries} ->
        Enum.map(entries, fn name -> %Japanese.Corpus.Story{name: name} end)

      _ ->
        []
    end
  end
end
