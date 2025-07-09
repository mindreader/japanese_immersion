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
  Updates the Japanese text for this page.
  Returns :ok or {:error, reason}.
  """
  @spec update_japanese_text(t, String.t()) :: :ok | {:error, term}
  def update_japanese_text(%__MODULE__{number: number, story: story}, new_text) do
    case StorageLayer.new() |> StorageLayer.update_japanese_page(story, number, new_text) do
      :ok ->
        Japanese.Translation.Service.translate_page(%__MODULE__{
          number: number,
          story: story,
          translated?: false
        })

      error ->
        error
    end
  end

  @doc """
  Updates the English translation for this page.
  Returns :ok or {:error, reason}.
  """
  @spec update_translation(t, String.t()) :: :ok | {:error, term}
  def update_translation(%__MODULE__{number: number, story: story}, new_translation) do
    StorageLayer.new() |> StorageLayer.write_english_translation(story, number, new_translation)
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
