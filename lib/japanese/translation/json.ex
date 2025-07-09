defmodule Japanese.Translation.Json do
  @moduledoc """
  Provides functions to pair Japanese and English (before and after translation) and return JSON.
  """

  @type translation_entry ::
          %{japanese: String.t(), english: String.t()} | %{paragraph_break: true}
  @type translation_json :: %{title: String.t(), translation: [translation_entry]}

  @doc """
  Takes Japanese and English text, before and after translation, and returns JSON.
  """
  @spec format_to_translation_json(String.t()) :: String.t()
  def format_to_translation_json(translation) do
    translation =
      translation
      |> String.split("\n", trim: true)
      |> Enum.chunk_by(&(&1 == "!CONTINUED!"))
      |> Enum.flat_map(fn
        ["!CONTINUED!"] ->
          [%{"paragraph_break" => true}]

        interleaves ->
          interleaves
          |> Enum.chunk_every(2)
          |> Enum.map(fn
            [japanese, english] -> %{"japanese" => japanese, "english" => english}
            _ -> nil
          end)
          |> Enum.reject(&is_nil/1)
      end)

    %{"title" => "TODO", "translation" => translation}
    |> Jason.encode!(pretty: pretty_json())
  end

  @spec decode_translation(String.t()) :: {:ok, translation_json} | {:error, term}
  def decode_translation(json) do
    json |> Jason.decode(keys: &decode_key/1)
  end

  # allow us to decode into atoms safely
  defp decode_key(x) do
    case x do
      "title" -> :title
      "japanese" -> :japanese
      "english" -> :english
      "translation" -> :translation
      "paragraph_break" -> :paragraph_break
      _ -> raise "#{__MODULE__}: Unknown key: #{x}"
    end
  end

  defp config do
    Application.get_env(:japanese, __MODULE__, [])
  end

  defp pretty_json do
    setting = config()

    if !is_nil(setting[:pretty_json]) do
      setting[:pretty_json]
    else
      false
    end
  end
end
