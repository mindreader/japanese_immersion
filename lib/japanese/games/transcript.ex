defmodule Japanese.Games.Transcript do
  @moduledoc """
  Parses and tidies Claude's screenshot transcription (see
  `priv/games/screenshot.txt`) into the shape stored on a
  `Japanese.Games.Shot`.

  Two clean-ups happen in code rather than being trusted to the prompt:

    * **English-only lines become labels.** A line with no Japanese in it
      (`ITEM`, `None`, `LV. 15`) has nothing to read or translate, so it is
      moved to the section's `"labels"` (keeping its focus) instead of being
      shown as a study line. Nothing is dropped: the text is still on screen
      for layout and context.
    * **Japanese not seen by OCR is flagged.** Vision decides which characters
      are on screen. A line containing Japanese characters that appear
      nowhere in the OCR text, and that the model did not itself mark as
      `ocr_missed`, gets `"unverified": true` so the UI can show it was the
      model's reading, not the OCR's.

  Sections are string-keyed maps:

      %{"name" => "dialogue", "speaker" => "Fred",
        "lines" => [%{"ja" => ..., "reading" => ..., "en" => ..., "focused" => true}],
        "labels" => ["ITEM"], "focused_label" => "ITEM"}
  """

  @type t :: %{
          description: String.t() | nil,
          kind: String.t() | nil,
          pointer: String.t() | nil,
          sections: [map()]
        }

  @japanese ~r/[\p{Hiragana}\p{Katakana}\p{Han}]/u

  @line_keys ~w(ja reading en focused ocr_note ocr_missed)

  @doc """
  Parses the model's reply (one JSON object, possibly wrapped in a code
  fence or a sentence) and cleans it against the OCR text.
  """
  @spec parse(String.t(), String.t()) :: {:ok, t()} | {:error, term()}
  def parse(reply, ocr_text) when is_binary(reply) and is_binary(ocr_text) do
    with {:ok, json} <- extract_json(reply),
         {:ok, map} when is_map(map) <- Jason.decode(json) do
      ocr_chars = japanese_chars(ocr_text)

      {:ok,
       %{
         description: string_or_nil(map["description"]),
         kind: string_or_nil(map["kind"]),
         pointer: string_or_nil(map["pointer"]),
         sections:
           map["sections"]
           |> List.wrap()
           |> Enum.filter(&is_map/1)
           |> Enum.map(&clean_section(&1, ocr_chars))
           |> Enum.reject(&empty_section?/1)
       }}
    else
      {:ok, _not_a_map} -> {:error, :invalid_transcript}
      {:error, %Jason.DecodeError{}} -> {:error, :invalid_transcript}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  True if the text contains any hiragana, katakana or kanji.
  """
  @spec japanese?(String.t()) :: boolean()
  def japanese?(text) when is_binary(text), do: Regex.match?(@japanese, text)
  def japanese?(_), do: false

  defp extract_json(reply) do
    case {:binary.match(reply, "{"), last_brace(reply)} do
      {{start, _}, stop} when is_integer(stop) and stop > start ->
        {:ok, binary_part(reply, start, stop - start + 1)}

      _ ->
        {:error, :invalid_transcript}
    end
  end

  defp last_brace(reply) do
    case :binary.matches(reply, "}") do
      [] -> nil
      matches -> matches |> List.last() |> elem(0)
    end
  end

  defp clean_section(section, ocr_chars) do
    {lines, moved} =
      section["lines"]
      |> List.wrap()
      |> Enum.filter(&(is_map(&1) and is_binary(&1["ja"]) and String.trim(&1["ja"]) != ""))
      |> Enum.split_with(&japanese?(&1["ja"]))

    labels =
      section["labels"]
      |> List.wrap()
      |> Enum.filter(&is_binary/1)
      |> Kernel.++(Enum.map(moved, &String.trim(&1["ja"])))
      |> Enum.uniq()

    focused_label =
      string_or_nil(section["focused_label"]) ||
        Enum.find_value(moved, fn line -> if line["focused"], do: String.trim(line["ja"]) end)

    %{
      "name" => string_or_nil(section["name"]) || "text",
      "lines" => Enum.map(lines, &clean_line(&1, ocr_chars)),
      "labels" => labels
    }
    |> put_present("speaker", string_or_nil(section["speaker"]))
    |> put_present("focused_label", focused_label)
  end

  defp clean_line(line, ocr_chars) do
    line =
      line
      |> Map.take(@line_keys)
      |> Map.update!("ja", &String.trim/1)

    if line["ocr_missed"] != true and
         not MapSet.subset?(japanese_chars(line["ja"]), ocr_chars) do
      Map.put(line, "unverified", true)
    else
      line
    end
  end

  defp empty_section?(%{"lines" => [], "labels" => []}), do: true
  defp empty_section?(_), do: false

  defp japanese_chars(text) do
    @japanese
    |> Regex.scan(text)
    |> List.flatten()
    |> MapSet.new()
  end

  defp put_present(map, _key, nil), do: map
  defp put_present(map, key, value), do: Map.put(map, key, value)

  defp string_or_nil(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp string_or_nil(_), do: nil
end
