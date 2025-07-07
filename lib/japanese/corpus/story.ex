defmodule Japanese.Corpus.Story do
  @moduledoc """
  Struct representing a story (corpus/collection) in the Japanese-English corpus.
  - :name  — the story's directory name (string)
  """
  alias Japanese.Corpus.Page

  @type t :: %__MODULE__{
          name: String.t()
        }
  defstruct name: nil

  @doc """
  Lists all pages in the story directory (returns a list of %Japanese.Corpus.Page{} structs).
  """
  @spec list_pages(t, String.t()) :: [Page.t()]
  def list_pages(story, root_dir \\ "txt"), do: pair_files(story, root_dir)

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
  @spec list_japanese_files(t, String.t()) :: [String.t()]
  def list_japanese_files(%__MODULE__{name: name}, root_dir \\ "txt") do
    story_dir = Path.join(root_dir, name)
    Japanese.Corpus.list_files_with_extension(story_dir, "j.md")
  end

  @doc """
  Pairs Japanese files (ending with 'j.md') with their corresponding English files (ending with 'e.md') in the story directory.
  Returns a list of %Japanese.Corpus.Page{} structs: %{number, japanese, english}
  If the English file is missing, :english will be nil.

  ## Example

      iex> stories = Japanese.Corpus.list_stories()
      iex> Japanese.Corpus.Story.pair_files(Enum.at(stories, 0))
      # => [
      #   %Japanese.Corpus.Page{number: "1", japanese: "1j.md", english: "1e.md"},
      #   %Japanese.Corpus.Page{number: "2", japanese: "2j.md", english: nil}
      # ]
  """
  @spec pair_files(t, String.t()) :: [Page.t()]
  def pair_files(%__MODULE__{name: name}, root_dir \\ "txt") do
    story_dir = Path.join(root_dir, name)
    jap_files = Japanese.Corpus.list_files_with_extension(story_dir, "j.md")

    jap_files
    |> Enum.map(fn jap_file ->
      number = String.replace_suffix(jap_file, "j.md", "") |> String.to_integer()
      eng_file = Integer.to_string(number) <> "e.md"
      eng_path = Path.join(story_dir, eng_file)

      %Page{
        number: number,
        japanese: jap_file,
        english: if(File.exists?(eng_path), do: eng_file, else: nil),
        root_dir: story_dir
      }
    end)
  end

  @doc """
  Creates a new story directory under the given root directory (default: "txt/").
  Returns {:ok, %Japanese.Corpus.Story{}} on success, {:error, reason} on failure.
  """
  @spec create(String.t(), String.t()) :: {:ok, t} | {:error, term}
  def create(name, root_dir \\ "txt") do
    story_dir = Path.join(root_dir, name)

    case File.mkdir(story_dir) do
      :ok -> {:ok, %__MODULE__{name: name}}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Adds a new Japanese page to the end of an existing story.
  Takes the story struct, the Japanese text, and the root directory (default: "txt/").
  Creates a new file with the next available number (e.g., "3j.md").
  Returns {:ok, file_name} on success, {:error, reason} on failure.
  """
  @spec add_japanese_page(t, String.t(), String.t()) :: {:ok, String.t()} | {:error, term}
  def add_japanese_page(%__MODULE__{name: name}, text, root_dir \\ "txt") do
    story_dir = Path.join(root_dir, name)
    jap_files = Japanese.Corpus.list_files_with_extension(story_dir, "j.md")

    next_number =
      jap_files
      |> Enum.map(fn file ->
        file |> String.replace_suffix("j.md", "") |> Integer.parse() |> elem(0)
      end)
      |> Enum.max(fn -> 0 end)
      |> Kernel.+(1)
      |> Integer.to_string()

    file_name = next_number <> "j.md"
    file_path = Path.join(story_dir, file_name)

    case File.write(file_path, text) do
      :ok -> {:ok, file_name}
      {:error, reason} -> {:error, reason}
    end
  end
end
