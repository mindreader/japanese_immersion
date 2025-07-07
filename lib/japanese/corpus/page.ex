defmodule Japanese.Corpus.Page do
  @moduledoc """
  Struct representing a page in a story.
  - :number   — the page number as an integer
  - :story    — the story name as a string
  """
  alias Japanese.Corpus.StorageLayer

  @type t :: %__MODULE__{
          number: integer(),
          story: String.t()
        }
  defstruct number: nil, story: nil

  @doc """
  Adds or updates the English translation for an existing Japanese page.
  Takes the page struct and the translation text.
  Delegates to the storage layer to determine the filename and do the write.
  Returns {:ok, :written} on success, {:error, reason} on failure.
  """
  @spec translate(t, String.t()) :: {:ok, :written} | {:error, term}
  def translate(%__MODULE__{number: number, story: story}, text) do
    StorageLayer.new()
    |> StorageLayer.write_translation(story, number, :english, text)
  end
end
