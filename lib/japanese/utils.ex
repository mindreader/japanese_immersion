defmodule Japanese.Utils do
  @moduledoc """
  Utility functions for the Japanese application.
  """

  alias Japanese.Corpus.Page

  @doc """
  Takes a page and returns a list of Japanese-English statement pairs.

  - Skips paragraph breaks
  - Filters out entries where English translation is less than 25 characters
  - Returns list of maps with :japanese (original), :japanese_tts (cleaned for TTS), and :english keys

  ## Examples

      iex> page = %Page{story: "testing", number: 1}
      iex> Japanese.Utils.parse_japanese_statements(page)
      {:ok, [%{japanese: "「来訪者　②」", japanese_tts: "来訪者　②", english: "Visitor ②"}, ...]}

  """
  @spec parse_japanese_statements(Page.t()) ::
          {:ok, [%{japanese: String.t(), japanese_tts: String.t(), english: String.t()}]}
          | {:error, term()}
  def parse_japanese_statements(%Page{} = page) do
    case Page.get_translation(page) do
      {:ok, %{translation: translation}} ->
        statements =
          translation
          |> Enum.reject(&Map.has_key?(&1, :paragraph_break))
          |> Enum.map(fn entry ->
            %{
              japanese: entry.japanese,
              japanese_tts: clean_japanese_for_tts(entry.japanese),
              english: entry.english
            }
          end)
          |> Enum.filter(fn entry ->
            String.length(entry.english) >= 25
          end)

        {:ok, statements}

      error ->
        error
    end
  end

  defp clean_japanese_for_tts(text) do
    text
    |> String.replace("「", "")
    |> String.replace("」", "")
    |> String.replace("『", "")
    |> String.replace("』", "")
    |> String.replace("。", "")
    |> String.replace("―", "")
    |> String.replace("、", "")
  end
end
