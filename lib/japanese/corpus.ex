defmodule Japanese.Corpus do
  @moduledoc """
  High-level entry point for accessing and managing the Japanese-English text corpus.

  This module provides functions to list stories (each a directory on disk) and to work with
  file-backed pages and translations. All data is stored in the filesystem, not a database.

  Features:
  - List stories (directories) in the corpus
  - Each story contains numbered Japanese and English page files (e.g., "1j.md", "1e.md")
  - See `Japanese.Corpus.Story` and `Japanese.Corpus.Page` for more operations
  """

  alias Japanese.Corpus.Story
  alias Japanese.Corpus.StorageLayer

  @doc """
  List all stories (directories) in the corpus root.

  Returns a list of %Japanese.Corpus.Story{} structs (with only the name field set),
  or an empty list if no stories are found.
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
