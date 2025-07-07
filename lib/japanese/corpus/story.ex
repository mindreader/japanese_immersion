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
  Lists all Japanese files (ending with 'j.md') in the story directory.
  Returns a list of file names as strings.

  ## Example

      iex> stories = Japanese.Corpus.list_stories()
      iex> stories |> Enum.map(fn story ->
      ...>   {story.name, Japanese.Corpus.Story.list_japanese_files(story)}
      ...> end)
      # => [{"story1", ["1j.md", "2j.md"]}, {"story2", ["1j.md"]}, ...]

  """
  @spec list_japanese_files(t) :: [String.t()]
  def list_japanese_files(%__MODULE__{name: name}) do
    StorageLayer.new()
    |> StorageLayer.list_japanese_files(name)
    |> case do
      {:ok, files} -> files
      _ -> []
    end
  end

  @doc """
  Pairs Japanese files (ending with 'j.md') with their corresponding English files (ending with 'e.md') in the story directory.
  Returns a list of %Japanese.Corpus.Page{} structs: %{number, story}
  """
  @spec pair_files(t) :: [Page.t()]
  def pair_files(story), do: list_pages(story)

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
end
