defmodule Japanese.Translation do
  @moduledoc """
  Provides translation functions between Japanese and English using an LLM backend (Anthropic via anthropix).

  ## Functions
  - `ja_to_en/2`: Japanese to English translation with options for literalness, formality, and extras.
  - `en_to_ja/2`: English to Japanese translation (future extensibility for options).
  """

  @model "claude-sonnet-4-20250514"

  @type ja_to_en_opts :: [
          literalness: :literal | :natural,
          translation_notes: boolean()
        ]

  @type ja_to_en_result :: %{
          optional(:formality) => String.t(),
          optional(:notes) => String.t(),
          optional(:ambiguities) => String.t(),
          text: String.t()
        }

  alias Japanese.Schemas.Anthropic.Response

  defmodule EnglishResponse do
    @enforce_keys [:text, :usage]
    defstruct [:text, :usage]
    @type t :: %__MODULE__{
      text: String.t(),
      usage: Response.t()
    }
  end

  @doc false
  @spec build_ja_to_en_prompt(Keyword.t()) :: String.t()
  defp build_ja_to_en_prompt(opts) do
    literalness = Keyword.get(opts, :literalness, :literal)
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

    extras_part =
      if translation_notes do
        " Provide translation notes, such as idioms, cultural context, or ambiguous phrases, if relevant."
      else
        ""
      end

    base <> extras_part
  end

  @doc false
  @spec build_client() :: map()
  defp build_client do
    api_key = Application.fetch_env!(:japanese, :anthropic_api_key)

    if is_nil(api_key) do
      raise "ANTHROPIC_API_KEY is not set in config or environment"
    end

    Anthropix.init(api_key)
  end

  @doc """
  Translates Japanese text to English.

  ## Options
    - `:literalness` - `:literal` or `:natural` (default: `:literal`)
    - `:translation_notes` - boolean, whether to provide translation notes (default: `false`)

  Returns a map with at least `:text` (the translation), and optionally `:notes`, `:ambiguities`.
  """
  @spec ja_to_en(String.t(), ja_to_en_opts()) :: EnglishResponse.t() | {:error, term()}
  def ja_to_en(text, opts \\ []) when is_binary(text) and is_list(opts) do
    client = build_client()
    prompt = build_ja_to_en_prompt(opts)

    Anthropix.chat(
      client,
      model: @model,
      messages: [
        %{role: "user", content: text}
      ],
      system: prompt
    )
    |> case do
      {:ok, anthropix_result} ->
        case Response.parse_response(anthropix_result) do
          {:ok, %{content: [%{text: text}], usage: usage}} ->
            %EnglishResponse{text: text, usage: usage}
          {:ok, %{content: []}} ->
            {:error, :no_content}
          {:ok, %{content: _messages}} ->
            {:error, :multiple_messages}

          {:error, changeset} ->
            {:error, changeset}
        end
      {:error, err} ->
        {:error, err}
    end
  end

  @doc """
  Translates English text to Japanese.

  ## Options
    - Currently no options, but may be extended in the future.

  Returns a map with at least `:text` (the translation).
  """
  @spec en_to_ja(String.t(), Keyword.t()) :: %{text: String.t()} | {:error, term()}
  def en_to_ja(text, opts \\ []) when is_binary(text) and is_list(opts) do
    :unimplemented
  end
end
