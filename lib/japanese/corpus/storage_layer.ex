defmodule Japanese.Corpus.StorageLayer do
  @moduledoc """
  Abstraction for corpus data access, scoped to a working directory.
  All operations are relative to the working directory, but the API is domain-centric.
  """

  @enforce_keys [:working_directory]
  defstruct working_directory: nil

  @type t :: %__MODULE__{
          working_directory: String.t()
        }

  @doc """
  Lists all stories (subdirectories) in the corpus.
  """
  @spec list_stories(t()) :: {:ok, [String.t()]} | {:error, term()}
  def list_stories(%__MODULE__{working_directory: wd}) do
    case File.ls(wd) do
      {:ok, entries} ->
        stories =
          entries
          |> Enum.filter(fn entry ->
            path = Path.join(wd, entry)
            File.dir?(path)
          end)

        {:ok, stories}

      error ->
        error
    end
  end

  @doc """
  Lists all pages (filenames) in a given story.
  """
  @spec list_pages(t(), String.t()) :: {:ok, [String.t()]} | {:error, term()}
  def list_pages(%__MODULE__{working_directory: wd}, story) do
    story_dir = Path.join(wd, story)

    case File.ls(story_dir) do
      {:ok, entries} ->
        pages =
          entries
          |> Enum.filter(fn entry ->
            File.regular?(Path.join(story_dir, entry))
          end)

        {:ok, pages}

      error ->
        error
    end
  end

  @doc """
  Reads the contents of a page (file) in a given story.
  """
  @spec read_page(t(), String.t(), String.t()) :: {:ok, String.t()} | {:error, term()}
  def read_page(%__MODULE__{working_directory: wd}, story, page) do
    file_path = Path.join([wd, story, page])
    File.read(file_path)
  end

  @doc """
  Writes contents to a page (file) in a given story. Creates the page if it does not exist.
  """
  @spec write_page(t(), String.t(), String.t(), String.t()) :: :ok | {:error, term()}
  def write_page(%__MODULE__{working_directory: wd}, story, page, contents) do
    file_path = Path.join([wd, story, page])
    File.write(file_path, contents)
  end

  @doc """
  Checks if a story exists.
  """
  @spec story_exists?(t(), String.t()) :: boolean()
  def story_exists?(%__MODULE__{working_directory: wd}, story) do
    story_dir = Path.join(wd, story)
    File.dir?(story_dir)
  end

  @doc """
  Creates a new story (subdirectory).
  """
  @spec create_story(t(), String.t()) :: :ok | {:error, term()}
  def create_story(%__MODULE__{working_directory: wd}, story) do
    story_dir = Path.join(wd, story)
    File.mkdir(story_dir)
  end

  @doc """
  Deletes a story (subdirectory and all its pages).
  """
  @spec delete_story(t(), String.t()) :: :ok | {:error, term()}
  def delete_story(%__MODULE__{working_directory: wd}, story) do
    story_dir = Path.join(wd, story)

    File.rm_rf(story_dir)
    |> case do
      {_, []} -> :ok
      {_, errors} -> {:error, errors}
    end
  end

  @doc """
  Deletes a page (file) in a given story.
  """
  @spec delete_page(t(), String.t(), String.t()) :: :ok | {:error, term()}
  def delete_page(%__MODULE__{working_directory: wd}, story, page) do
    file_path = Path.join([wd, story, page])
    File.rm(file_path)
  end
end
