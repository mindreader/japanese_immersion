defmodule Japanese.Corpus.Story do
  @moduledoc """
  Struct representing a story (corpus/collection) in the Japanese-English corpus.
  - :name  — the story's directory name (string)
  """
  alias Japanese.Corpus.Page
  alias Japanese.Corpus.StorageLayer

  @type t :: %__MODULE__{
          name: String.t()
        }
  defstruct name: nil

  @doc """
  Lists all pages in the story directory (returns a list of %Japanese.Corpus.Page{} structs).
  """
  @spec list_pages(t) :: [Page.t()]
  def list_pages(%__MODULE__{name: name}) do
    storage = StorageLayer.new()

    case StorageLayer.pair_files(storage, name) do
      {:ok, pairs} ->
        Enum.map(pairs, fn %{number: number} ->
          %Page{number: number, story: name}
        end)

      _ ->
        []
    end
  end

  @doc """
  Creates a new story directory.
  Returns {:ok, %Japanese.Corpus.Story{}} on success, {:error, reason} on failure.
  """
  @spec create(String.t()) :: {:ok, t} | {:error, term}
  def create(name) do
    StorageLayer.new()
    |> StorageLayer.create_story(name)
    |> case do
      :ok -> {:ok, %__MODULE__{name: name}}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Adds a new Japanese page to the end of an existing story.
  Takes the story struct and the Japanese text.
  Creates a new file with the next available number (e.g., "3j.md").
  Returns {:ok, %Page{}} on success, {:error, reason} on failure.
  """
  @spec add_japanese_page(t, String.t()) :: {:ok, Page.t()} | {:error, term}
  def add_japanese_page(%__MODULE__{name: name} = _story, text) do
    storage = StorageLayer.new()
    file_name = StorageLayer.next_page_filename(storage, name)

    case storage |> StorageLayer.write_page(name, file_name, text) do
      :ok ->
        number = StorageLayer.extract_page_number(file_name)
        {:ok, %Page{number: number, story: name}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Deletes the story and all its files.
  Returns :ok if successful, {:error, reason} otherwise.
  """
  @spec delete(t) :: :ok | {:error, term}
  def delete(%__MODULE__{name: name}) do
    StorageLayer.new()
    |> StorageLayer.delete_story(name)
  end
end
