defmodule Japanese.Corpus.StorageLayer do
  @moduledoc """
  Provides file-based storage and access for the Japanese-English corpus.

  All operations are performed relative to a working directory, with each story as a subdirectory
  and each page as a file within its story directory. Japanese and English content are stored in
  separate files (e.g., "1j.md" for Japanese, "1e.md" for English).
  """

  @enforce_keys [:working_directory]
  defstruct working_directory: nil

  @type t :: %__MODULE__{
          working_directory: String.t()
        }

  @doc """
  Create a new StorageLayer struct using the working directory from config (:japanese, :corpus_dir).
  Raises if the config is missing.
  """
  @spec new() :: t()
  def new() do
    working_directory =
      Application.get_env(:japanese, :corpus_dir) ||
        raise "Missing :corpus_dir in :japanese config"

    %__MODULE__{working_directory: working_directory}
  end

  # --- FILENAME CONVENTIONS ---
  @japanese_suffix "j.txt"
  @translation_suffix "tr.yaml"

  @doc """
  Returns true if the filename is a Japanese page file (e.g., "1j.txt").
  """
  def is_japanese_file?(filename) do
    String.ends_with?(filename, @japanese_suffix) and
      filename =~ ~r/^\d+j\.txt$/
  end

  @doc """
  Returns true if the filename is a translation file (e.g., "1tr.yaml").
  """
  def is_translation_file?(filename) do
    String.ends_with?(filename, @translation_suffix) and
      filename =~ ~r/^\d+tr\.yaml$/
  end

  @doc """
  Extract the page number from a Japanese or English filename.
  Returns an integer or nil if not a valid page file.
  """
  def extract_page_number(filename) do
    cond do
      is_japanese_file?(filename) ->
        filename |> String.replace_suffix(@japanese_suffix, "") |> String.to_integer()

      is_translation_file?(filename) ->
        filename |> String.replace_suffix(@translation_suffix, "") |> String.to_integer()

      true ->
        nil
    end
  end

  @doc """
  List all Japanese files in a given story directory.
  Returns {:ok, [filename]} or {:error, reason}.
  """
  @spec list_japanese_files(t(), String.t()) :: {:ok, [String.t()]} | {:error, term()}
  def list_japanese_files(%__MODULE__{working_directory: wd}, story) do
    with {:ok, files} <- list_pages(%__MODULE__{working_directory: wd}, story) do
      {:ok, Enum.filter(files, &is_japanese_file?/1)}
    end
  end

  @doc """
  Pair Japanese files with their corresponding translation files in a story.

  Returns a list of maps: %{number, japanese, translation}, where :translation may be nil if missing.
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
          tr_file = Integer.to_string(number) <> @translation_suffix
          tr_path = Path.join(story_dir, tr_file)

          %{
            number: number,
            japanese: jap_file,
            translation: if(File.exists?(tr_path), do: tr_file, else: nil)
          }
        end)

      {:ok, pairs}
    end
  end

  @doc """
  List all stories (subdirectories) in the corpus working directory.
  Returns {:ok, [story_name]} or {:error, reason}.
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
  List all page filenames in a given story directory.
  Returns {:ok, [filename]} or {:error, reason}.
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

  #  @spec read_page(t(), String.t(), String.t()) :: {:ok, String.t()} | {:error, term()}
  #  defp read_page(%__MODULE__{working_directory: wd}, story, page) do
  #    file_path = Path.join([wd, story, page])
  #    File.read(file_path)
  #  end

  @spec write_page(t(), String.t(), String.t(), String.t()) :: :ok | {:error, term()}
  defp write_page(%__MODULE__{working_directory: wd}, story, page, contents) do
    file_path = Path.join([wd, story, page])
    File.write(file_path, contents)
  end

  @doc """
  Check if a story directory exists.
  Returns true if the directory exists, false otherwise.
  """
  @spec story_exists?(t(), String.t()) :: boolean()
  def story_exists?(%__MODULE__{working_directory: wd}, story) do
    story_dir = Path.join(wd, story)
    File.dir?(story_dir)
  end

  @doc """
  Create a new story directory.
  Returns :ok or {:error, reason}.
  """
  @spec create_story(t(), String.t()) :: :ok | {:error, term()}
  def create_story(%__MODULE__{working_directory: wd}, story) do
    story_dir = Path.join(wd, story)
    File.mkdir(story_dir)
  end

  @doc """
  Delete a story directory and all its page files.
  Returns :ok if successful, or {:error, reason} if deletion fails.
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
  Delete both the Japanese and English page files for the given story and page number.
  Returns :ok if both are deleted or do not exist, or {:error, reason} if any error occurs.
  """
  @spec delete_page(t(), String.t(), integer()) :: :ok | {:error, term}
  def delete_page(%__MODULE__{} = storage, story, number) do
    jap_file = page_filename(storage, story, number, :japanese)
    eng_file = page_filename(storage, story, number, :translation)
    jap_result = delete_file(storage, story, jap_file)
    eng_result = delete_file(storage, story, eng_file)

    case {jap_result, eng_result} do
      {:ok, :ok} -> :ok
      {:ok, {:error, :enoent}} -> :ok
      {{:error, :enoent}, _} -> {:error, :enoent}
      {{:error, reason}, _} -> {:error, reason}
      {_, {:error, reason}} when reason != :enoent -> {:error, reason}
    end
  end

  defp delete_file(%__MODULE__{working_directory: wd}, story, filename) do
    file_path = Path.join([wd, story, filename])

    case File.rm(file_path) do
      :ok -> :ok
      {:error, :enoent} -> {:error, :enoent}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Write an English translation for a page, given the story, page number, and the English text.
  Returns {:ok, :written} or {:error, reason}.
  """
  @spec write_english_translation(t(), String.t(), integer(), String.t()) ::
          {:ok, :written} | {:error, term}
  def write_english_translation(storage, story, number, english) do
    filename = page_filename(storage, story, number, :translation)

    case write_page(storage, story, filename, english) do
      :ok -> {:ok, :written}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Update the Japanese text for a page, given the story, page number, and new text.
  Returns :ok or {:error, reason}.
  """
  @spec update_japanese_page(t(), String.t(), integer(), String.t()) :: :ok | {:error, term}
  def update_japanese_page(storage, story, number, new_text) do
    filename = page_filename(storage, story, number, :japanese)
    write_page(storage, story, filename, new_text)
  end

  @doc """
  Get the filename for a specific page number and type.
  Returns a string like "1j.txt" or "1tr.yaml".
  """
  @spec page_filename(t(), String.t(), integer(), :japanese | :translation) :: String.t()
  def page_filename(_storage, _story, number, :japanese),
    do: Integer.to_string(number) <> @japanese_suffix

  def page_filename(_storage, _story, number, :translation),
    do: Integer.to_string(number) <> @translation_suffix

  @doc """
  Get the next available filename for a new Japanese page in the given story.
  Returns a string like "3j.txt".
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

  @doc """
  Create a new Japanese page in the given story with the provided text.
  Determines the next available page number and filename, writes the file, and returns {:ok, %Page{}} or {:error, reason}.
  """
  @spec create_japanese_page(t(), String.t(), String.t()) ::
          {:ok, Japanese.Corpus.Page.t()} | {:error, term}
  def create_japanese_page(storage, story, text) do
    file_name = next_page_filename(storage, story)

    case write_page(storage, story, file_name, text) do
      :ok ->
        number = extract_page_number(file_name)
        {:ok, %Japanese.Corpus.Page{number: number, story: story}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Rename a story directory from old_name to new_name.
  Returns :ok if successful, or {:error, reason} if renaming fails.
  """
  @spec rename_story(t(), String.t(), String.t()) :: :ok | {:error, term()}
  def rename_story(%__MODULE__{working_directory: wd}, old_name, new_name) do
    old_dir = Path.join(wd, old_name)
    new_dir = Path.join(wd, new_name)

    cond do
      !File.dir?(old_dir) ->
        {:error, :not_found}

      File.dir?(new_dir) ->
        {:error, :already_exists}

      true ->
        case File.rename(old_dir, new_dir) do
          :ok -> :ok
          {:error, reason} -> {:error, reason}
        end
    end
  end

  @doc """
  Get the Japanese text for a given story and page number.
  Returns {:ok, text} or {:error, reason}.
  """
  @spec get_japanese_text(t(), String.t(), integer()) :: {:ok, String.t()} | {:error, term}
  def get_japanese_text(storage, story, number) do
    filename = page_filename(storage, story, number, :japanese)
    file_path = Path.join([storage.working_directory, story, filename])
    File.read(file_path)
  end
end
