defmodule Japanese.Corpus.Page do
  @moduledoc """
  Struct representing a Japanese-English file page for a story.
  - :number   — the page number as an integer
  - :japanese — the Japanese file name (string)
  - :english  — the English file name (string or nil if missing)
  - :root_dir — the root directory of the story (string, defaults to "txt")
  """
  @type t :: %__MODULE__{
          number: integer(),
          japanese: String.t(),
          english: String.t() | nil,
          root_dir: String.t()
        }
  defstruct number: nil, japanese: nil, english: nil, root_dir: "txt"

  @doc """
  Adds or updates the English translation for an existing Japanese page.
  Takes the page struct and the translation text.
  Creates or overwrites the corresponding English file (e.g., "1e.md") in the page's root_dir.
  Returns {:ok, file_name} on success, {:error, reason} on failure.
  """
  @spec translate(t, String.t()) :: {:ok, String.t()} | {:error, term}
  def translate(%__MODULE__{number: number, root_dir: root_dir}, text) do
    file_name = Integer.to_string(number) <> "e.md"
    file_path = Path.join(root_dir, file_name)

    case File.write(file_path, text) do
      :ok -> {:ok, file_name}
      {:error, reason} -> {:error, reason}
    end
  end
end
