defmodule Japanese.Corpus.Page do
  @moduledoc """
  Struct representing a page in a story.
  - :number   — the page number as an integer
  - :story    — the story name as a string
  - :translated? — whether the page has been translated (boolean)
  """

  require Logger
  alias Japanese.Corpus.StorageLayer

  @type t :: %__MODULE__{
          number: integer(),
          story: String.t(),
          translated?: boolean()
        }
  defstruct number: nil, story: nil, translated?: false

  @doc """
  Translates the Japanese text for this page to English using the Japanese.Translation module.
  Returns the translation result (not written to file). This could take some time...
  """
  @spec translate_page(t) :: :ok | {:error, term}
  def translate_page(%__MODULE__{translated?: true}), do: {:error, :already_translated}
  def translate_page(page) do
    with {:ok, japanese_text} <- get_japanese_text(page),
         %Japanese.Translation{text: interleaved_translation} <-
           Japanese.Translation.ja_to_en(japanese_text, interleaved: true) do
      json = Japanese.Translation.Json.format_to_translation_json(interleaved_translation)

      StorageLayer.new()
      |> StorageLayer.write_english_translation(page.story, page.number, json)

      :ok
    else
      {:error, reason} -> {:error, reason}
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

  @doc """
  Gets the Japanese text for this page from the storage layer.
  Returns {:ok, text} or {:error, reason}.
  """
  @spec get_japanese_text(t) :: {:ok, String.t()} | {:error, term}
  def get_japanese_text(%__MODULE__{number: number, story: story}) do
    StorageLayer.new() |> StorageLayer.get_japanese_text(story, number)
  end

  @doc """
  Gets the translation JSON for this page from the storage layer and returns it as a map.
  Returns {:ok, map} or {:error, reason}.
  """
  @spec get_translation(t) :: {:ok, Japanese.Translation.Json.translation_json()} | {:error, term}
  def get_translation(%__MODULE__{number: number, story: story}) do
    storage = StorageLayer.new()
    filename = StorageLayer.page_filename(storage, story, number, :translation)
    file_path = Path.join([storage.working_directory, story, filename])

    case File.read(file_path) do
      {:ok, json} ->
        json |> Japanese.Translation.Json.decode_translation()

      error ->
        error
    end
  end

  defimpl Phoenix.Param, for: Japanese.Corpus.Page do
    def to_param(%Japanese.Corpus.Page{number: number}), do: to_string(number)
  end
end
