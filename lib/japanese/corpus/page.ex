defmodule Japanese.Corpus.Page do
  @moduledoc """
  Struct representing a page in a story.
  - :number   — the page number as an integer
  - :story    — the story name as a string
  """

  require Logger
  alias Japanese.Corpus.StorageLayer

  @type t :: %__MODULE__{
          number: integer(),
          story: String.t()
        }
  defstruct number: nil, story: nil

  @doc """
  Translates the given Japanese text to English using the Japanese.Translation module.
  Returns the translation result (not written to file).
  """
  @spec translate_page(t, String.t()) :: :ok | {:error, term}
  def translate_page(page, japanese_text) do
    case Japanese.Translation.ja_to_en(japanese_text, interleaved: true) do
      %Japanese.Translation{text: interleaved_translation} ->
        json = Japanese.Translation.Json.format_to_translation_json(interleaved_translation)

        StorageLayer.new()
        |> StorageLayer.write_english_translation(page.story, page.number, json)

        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Deletes both the Japanese and English page files for this page.
  Returns :ok or {:error, reason}.
  """
  @spec delete(t) :: :ok | {:error, term}
  def delete(%__MODULE__{number: number, story: story}) do
    StorageLayer.new() |> StorageLayer.delete_page(story, number)
  end

  defimpl Phoenix.Param, for: Japanese.Corpus.Page do
    def to_param(%Japanese.Corpus.Page{number: number}), do: to_string(number)
  end
end
