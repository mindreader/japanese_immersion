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
  Creates a new StorageLayer struct using the working directory from config (:japanese, :corpus_dir).
  """
  @spec new() :: t()
  def new() do
    working_directory =
      Application.get_env(:japanese, :corpus_dir) ||
        raise "Missing :corpus_dir in :japanese config"

    %__MODULE__{working_directory: working_directory}
  end

  # --- FILENAME CONVENTIONS ---
  @japanese_suffix "j.md"
  @english_suffix "e.md"

  @doc """
  Returns true if the filename is a Japanese page file.
  """
  def is_japanese_file?(filename) do
    String.ends_with?(filename, @japanese_suffix) and
      filename =~ ~r/^\d+j\.md$/
  end

  @doc """
  Returns true if the filename is an English page file.
  """
  def is_english_file?(filename) do
    String.ends_with?(filename, @english_suffix) and
      filename =~ ~r/^\d+e\.md$/
  end

  @doc """
  Extracts the page number from a Japanese or English filename.
  Returns an integer or nil if not a valid page file.
  """
  def extract_page_number(filename) do
    cond do
      is_japanese_file?(filename) ->
        filename |> String.replace_suffix(@japanese_suffix, "") |> String.to_integer()

      is_english_file?(filename) ->
        filename |> String.replace_suffix(@english_suffix, "") |> String.to_integer()

      true ->
        nil
    end
  end

  @doc """
  Lists all Japanese files in a given story.
  """
  @spec list_japanese_files(t(), String.t()) :: {:ok, [String.t()]} | {:error, term()}
  def list_japanese_files(%__MODULE__{working_directory: wd}, story) do
    with {:ok, files} <- list_pages(%__MODULE__{working_directory: wd}, story) do
      {:ok, Enum.filter(files, &is_japanese_file?/1)}
    end
  end

  @doc """
  Pairs Japanese files with their corresponding English files in a story.
  Returns a list of maps: %{number, japanese, english}
  """
  @spec pair_files(t(), String.t()) :: {:ok, [map()]} | {:error, term()}
  def pair_files(%__MODULE__{working_directory: wd} = storage, story) do
    story_dir = Path.join(wd, story)

    with {:ok, files} <- list_pages(storage, story) do
      jap_files = Enum.filter(files, &is_japanese_file?/1)

      pairs =
        jap_files
        |> Enum.map(fn jap_file ->
          number = extract_page_number(jap_file)
          eng_file = Integer.to_string(number) <> @english_suffix
          eng_path = Path.join(story_dir, eng_file)

          %{
            number: number,
            japanese: jap_file,
            english: if(File.exists?(eng_path), do: eng_file, else: nil)
          }
        end)

      {:ok, pairs}
    end
  end

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

  @doc """
  Writes a translation (or original) for a page, given the story, page number, and content.
  Determines the filename (always Japanese) and writes the file.
  Returns {:ok, :written} or {:error, reason}.
  """
  @spec write_translation(t(), String.t(), integer(), String.t()) ::
          {:ok, :written} | {:error, term}
  def write_translation(storage, story, number, content) do
    filename = page_filename(storage, story, number, :japanese)

    case write_page(storage, story, filename, content) do
      :ok -> {:ok, :written}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Returns the filename for a specific page number and language.
  """
  @spec page_filename(t(), String.t(), integer(), :japanese | :english) :: String.t()
  def page_filename(_storage, _story, number, :japanese),
    do: Integer.to_string(number) <> @japanese_suffix

  def page_filename(_storage, _story, number, :english),
    do: Integer.to_string(number) <> @english_suffix

  @doc """
  Returns the next available filename for a new Japanese page in the given story.
  """
  @spec next_page_filename(t(), String.t()) :: String.t()
  def next_page_filename(storage, story) do
    {:ok, files} = list_japanese_files(storage, story)

    next_number =
      files
      |> Enum.map(&extract_page_number/1)
      |> Enum.reject(&is_nil/1)
      |> Enum.max(fn -> 0 end)
      |> Kernel.+(1)

    Integer.to_string(next_number) <> @japanese_suffix
  end
end
