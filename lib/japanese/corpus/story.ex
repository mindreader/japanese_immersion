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
        Enum.map(pairs, fn %{number: number, translation: translation} ->
          %Page{number: number, story: name, translated?: not is_nil(translation)}
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
  def add_japanese_page(%__MODULE__{name: name}, text) do
    StorageLayer.new() |> StorageLayer.create_japanese_page(name, text)
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

  @doc """
  Gets a story by name, ensuring it exists in storage.
  Returns {:ok, %Japanese.Corpus.Story{}} if found, {:error, :not_found} otherwise.
  """
  @spec get_by_name(String.t()) :: {:ok, t} | {:error, :not_found}
  def get_by_name(name) do
    storage = StorageLayer.new()

    if StorageLayer.story_exists?(storage, name) do
      {:ok, %__MODULE__{name: name}}
    else
      {:error, :not_found}
    end
  end

  @doc """
  Renames a story from old_name to new_name, ensuring the new name does not already exist.
  Returns {:ok, %Story{name: new_name}} or {:error, reason}.
  """
  @spec rename(String.t(), String.t()) :: {:ok, t} | {:error, term}
  def rename(old_name, new_name) do
    StorageLayer.new()
    |> StorageLayer.rename_story(old_name, new_name)
    |> case do
      :ok -> {:ok, %__MODULE__{name: new_name}}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Get a specific page by page number from a story struct.
  Returns {:ok, page} if found, or {:error, :not_found}.
  """
  @spec get_page(t(), integer()) :: {:ok, Page.t()} | {:error, :not_found}
  def get_page(story, page_number) do
    pages = list_pages(story)

    case Enum.find(pages, &(&1.number == page_number)) do
      nil -> {:error, :not_found}
      page -> {:ok, page}
    end
  end
end

defimpl Phoenix.Param, for: Japanese.Corpus.Story do
  def to_param(%Japanese.Corpus.Story{name: name}), do: name
end
