defmodule Japanese.Translation do
  @moduledoc """
  Provides translation functions between Japanese and English using an LLM backend (Anthropic via anthropix).

  This module is also a struct representing a translation result, with fields:
    - :text (the translated text)
    - :usage (the usage struct)
  """

  @model "claude-sonnet-4-20250514"

  @type ja_to_en_opts :: [
          literalness: :literal | :natural,
          translation_notes: boolean(),
          interleaved: boolean()
        ]

  @type ja_to_en_result :: %{
          optional(:formality) => String.t(),
          optional(:notes) => String.t(),
          optional(:ambiguities) => String.t(),
          text: String.t()
        }

  alias Japanese.Schemas.Anthropic.Response

  @enforce_keys [:text]
  defstruct [:text, :usage]

  @type t :: %__MODULE__{
          text: String.t(),
          usage: Japanese.Schemas.Anthropic.Response.Usage.t()
        }

  @doc """
  Translates Japanese text to English.

  ## Options
    - `:literalness` - `:literal` or `:natural` (default: `:literal`)
    - `:translation_notes` - boolean, whether to provide translation notes (default: `false`)

  Returns a map with at least `:text` (the translation), and optionally `:notes`, `:ambiguities`.
  """
  @spec ja_to_en(String.t(), ja_to_en_opts()) :: t() | {:error, term()}
  def ja_to_en(text, opts \\ []) when is_binary(text) and is_list(opts) do
    text = cleanup(text)

    opts
    |> build_ja_to_en_prompt()
    |> call_anthropix(text)
    |> handle_response(:ja_to_en)
  end

  def cleanup(japanese_text) do
    rows = japanese_text |> String.split("\n") |> Enum.map(&String.trim/1)

    # squash any sequences of 3 or more consecutive newlines into 2
    rows
    |> Enum.chunk_by(&(&1 == ""))
    |> Enum.map(fn
      ["", "", "" | _] -> ["", ""]
      xs -> xs
    end)
    |> Enum.concat()
    |> Enum.join("\n")
  end

  @doc """
  Translates English text to Japanese.

  ## Options
    - Currently no options, but may be extended in the future.

  Returns a map with at least `:text` (the translation).
  """
  @spec en_to_ja(String.t(), Keyword.t()) :: %{text: String.t()} | {:error, term()}
  def en_to_ja(text, opts \\ []) when is_binary(text) and is_list(opts) do
    opts
    |> build_en_to_ja_prompt()
    |> call_anthropix(text)
    |> handle_response(:en_to_ja)
  end

  defp build_ja_to_en_prompt(opts) do
    literalness = Keyword.get(opts, :literalness, :literal)
    interleaved = Keyword.get(opts, :interleaved, false)
    translation_notes = Keyword.get(opts, :translation_notes, false)

    base =
      case literalness do
        :literal ->
          "Translate this Japanese literally and directly and keep the exact same format as the input except translated. Do not add any additional commentary or explanation or assessment of formality."

        :natural ->
          "Translate this Japanese to natural English, making it sound fluent and idiomatic."

        _ ->
          "Translate this Japanese to English."
      end

    # TODO there is no need to have newlines between each original line and its single translation.
    interleaved_part =
      if interleaved do
        " Interleave the translation with the original text, so that we alternate between the original and the translation using the original text's paragraphs as the boundaries, ensuring that there is one newline between each pair. If the text seems to be transitioning from one scene to another, add a single line with the word '!CONTINUED!' between the two paragraphs."
      else
        ""
      end

    extras_part =
      if translation_notes do
        " Provide translation notes, such as idioms, cultural context, or ambiguous phrases, if relevant."
      else
        ""
      end

    base <> interleaved_part <> extras_part
  end

  defp build_en_to_ja_prompt(_opts) do
    "Translate this English text to Japanese. Keep the meaning and tone as close as possible."
  end

  defp build_client do
    api_key = Application.fetch_env!(:japanese, :anthropic_api_key)

    if is_nil(api_key) do
      raise "ANTHROPIC_API_KEY is not set in config or environment"
    end

    Anthropix.init(api_key)
  end

  defp call_anthropix(system_prompt, user_text) do
    client = build_client()

    Anthropix.chat(
      client,
      model: @model,
      messages: [
        %{role: "user", content: user_text}
      ],
      system: system_prompt
    )
    |> case do
      {:ok, anthropix_result} ->
        Response.parse_response(anthropix_result)

      {:error, err} ->
        {:error, err}
    end
  end

  defp handle_response({:ok, %{content: [%{text: text} | _], usage: usage}}, :ja_to_en),
    do: %__MODULE__{text: text, usage: usage}

  defp handle_response({:ok, %{content: [%{text: text} | _]}}, :en_to_ja) when is_binary(text),
    do: %{text: text}

  defp handle_response({:ok, %{content: []}}, _),
    do: {:error, :no_content}

  defp handle_response({:ok, %{content: _messages}}, _),
    do: {:error, :multiple_messages}

  defp handle_response({:error, err}, _),
    do: {:error, err}
end
