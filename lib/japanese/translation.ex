defmodule Japanese.Translation do
  @moduledoc """
  Provides translation functions between Japanese and English using an LLM backend (Anthropic via anthropix).

  This module is also a struct representing a translation result, with fields:
    - :text (the translated text)
    - :usage (the usage struct)

  ## Model selection

  The Anthropic model is configured rather than pinned in code (see `model/1`).
  We default to the unpinned `"claude-sonnet-5"` alias instead of a dated
  snapshot id: a dated id is perfectly reproducible but eventually gets
  deprecated and starts hard-failing, while an alias keeps working but means
  behaviour can drift underneath us without a code change. For this app's
  workload — bulk literal translation, judged mainly on faithfulness rather
  than creative quality — we're accepting that drift risk in exchange for not
  having to chase deprecations.
  """

  require Logger

  # Cheaper than an Opus-class model with a much larger output ceiling and a
  # 1M context, which comfortably covers whole-page interleaved translation.
  # Switching to "claude-opus-5" for higher quality is a config-only change
  # (see `model/1`) if this default ever proves insufficient.
  @default_model "claude-sonnet-5"

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
  alias Japanese.Translation.Json

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
    text = text |> cleanup() |> number_lines(Keyword.get(opts, :interleaved, false))

    opts
    |> build_ja_to_en_prompt()
    |> call_anthropix(text, :ja_to_en)
    |> handle_response(:ja_to_en)
  end

  # An interleaved translation is pasted back together line by line, so the
  # lines are numbered and the model is asked to answer by number: pairing
  # becomes a lookup instead of an inference about ordering.
  @spec number_lines(String.t(), boolean()) :: String.t()
  defp number_lines(text, true), do: Json.number_source_lines(text)
  defp number_lines(text, false), do: text

  @doc """
  Normalises Japanese page text the way the model will see it.

  Trims each line and squashes runs of three or more blank lines down to two.
  Pairing anchors against the result rather than the bytes on disk, because this
  is what was actually sent for translation.
  """
  @spec cleanup(String.t()) :: String.t()
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
    |> call_anthropix(text, :en_to_ja)
    |> handle_response(:en_to_ja)
  end

  @doc """
  Explains Japanese text in English, breaking it down piece by piece with romaji.

  Returns the explanation text as a string, or an error tuple.
  """
  @spec explain_text(String.t()) :: String.t() | {:error, term()}
  def explain_text(text) when is_binary(text) do
    system_prompt = """
    Break down this Japanese text into English, piece by piece. Use this format:

    **Example:**
    今日は晴れです。

    **Romaji:** Kyō wa hare desu.

    **Breakdown:**
    - 今日 (きょう, kyō) = today
    - は (wa) = topic particle
    - 晴れ (はれ, hare) = clear weather
    - です (desu) = polite copula "is"

    **Translation:** "Today is clear/sunny."

    For multiple sentences, use "Sentence 1", "Sentence 2", etc. as headers.
    Include romaji, word-by-word breakdowns with readings and meanings, and full translations.
    """

    text
    |> cleanup()
    |> then(&call_anthropix(system_prompt, &1, :explain))
    |> handle_response(:explain)
  end

  @doc """
  Explains a single conjugated verb form for the drill mode.

  Takes a context map describing the verb and the form, and returns a brief
  on-demand explanation. Designed to be short — only what the learner can't
  already see in the UI.
  """
  @spec explain_form(map()) :: String.t() | {:error, term()}
  def explain_form(ctx) when is_map(ctx) do
    system_prompt = """
    You are helping an intermediate Japanese learner who is drilling verb
    conjugations. They've been shown one conjugated form with its name and a
    short generic description. Now they want a short, focused note about
    this particular verb in this particular form.

    Keep it under 4 sentences. Be concrete. Cover whichever of these are
    relevant — skip what isn't:

    - Is this form rare, awkward, archaic, or unusual when applied to this
      verb? If so, say so plainly and suggest the form a native speaker
      would actually use.
    - Is the meaning quirky or non-obvious for this specific verb?
    - One short natural example sentence using this exact conjugation.

    Do NOT repeat the form name or the generic description (the learner
    already sees those). Do NOT lecture. Do NOT use headers or bullet lists.
    Plain prose, tight.
    """

    user = """
    Verb (dictionary form): #{ctx.verb_kanji || ctx.verb_kana} (#{ctx.verb_kana}) — "#{ctx.verb_english}"
    Verb class: #{ctx.verb_class}
    Form name (already shown to learner): #{ctx.form_label}
    Conjugated form: #{ctx.conjugated_kanji} (#{ctx.conjugated_kana})
    """

    call_anthropix(system_prompt, user, :explain)
    |> handle_response(:explain)
  end

  @doc """
  Looks up the kana reading of a selected word or phrase, as it is actually
  read within its containing sentence.

  Kanji readings are context-dependent (e.g. 行った is いった "went" or
  おこなった "carried out" depending on the sentence), so `context` — the full
  sentence/line the selection was taken from — is required, not optional.
  Sending the bare selection alone would let the model guess plausibly and
  wrongly with no way for the learner to notice.

  This is intentionally tiny and fast: no grammar breakdown, no translation,
  just the reading. If the model can't determine a confident reading from
  the given context, or if the response gets cut off before it could finish
  (a truncated reading is worse than no reading — it looks complete and is
  silently wrong), this returns `:unknown` or `{:error, reason}` respectively
  rather than a partial/guessed answer; callers should treat those as
  distinct "can't tell" cases rather than a real reading.
  """
  @spec reading_for(String.t(), String.t()) :: {:ok, String.t()} | :unknown | {:error, term()}
  def reading_for(selection, context) when is_binary(selection) and is_binary(context) do
    system_prompt = """
    You will be given a Japanese sentence and a word or phrase selected from
    within it. Reply with ONLY the kana reading of the selected portion,
    exactly as it is read in that sentence — kanji readings depend on
    surrounding context, so use the sentence to disambiguate (okurigana,
    compound readings, names, etc.).

    Rules:
    - Use hiragana for kanji and native Japanese vocabulary. If part of the
      selection is already katakana (loanwords, onomatopoeia, foreign
      names), keep that part in katakana exactly as written — do not
      convert it to hiragana, and do not alter the long vowel mark ー.
    - Reply with kana only. No romaji, no kanji, no translation, no
      punctuation, no explanation, nothing else.
    - The selection may be a whole sentence/line, not just a single word —
      transcribe all of it, not just part of it.
    - If you cannot determine the reading with reasonable confidence even
      given the sentence, reply with exactly: unknown
    """

    # Both sides are trimmed here as well as in the client: the context is
    # captured from a rendered element, so it can arrive carrying the
    # template's surrounding whitespace, and a sentence that begins with a
    # newline makes the labelled structure below harder to read, not easier.
    user = "Sentence: #{String.trim(context)}\nSelected portion: #{String.trim(selection)}"

    case call_anthropix(system_prompt, user, :reading, max_tokens: 512)
         |> handle_response(:reading) do
      {:error, reason} -> {:error, reason}
      text when is_binary(text) -> if unknown_reply?(text), do: :unknown, else: {:ok, text}
    end
  end

  defp unknown_reply?(text) do
    text
    |> String.downcase()
    |> String.replace(~r/[^\p{L}]/u, "")
    |> Kernel.==("unknown")
  end

  @doc """
  Translates the japanese page synchronously. This can often take some time...

  If you want to translate a page asynchronously, use the `Japanese.Translation.Service` module.
  """
  @spec translate_page(Japanese.Corpus.Page.t()) :: :ok | {:error, term}
  def translate_page(%Japanese.Corpus.Page{translated?: true}), do: {:error, :already_translated}

  def translate_page(page) do
    alias Japanese.Corpus.Story
    alias Japanese.Corpus.Page

    with {:ok, japanese_text} <- Page.get_japanese_text(page),
         %__MODULE__{text: interleaved_translation} <-
           ja_to_en(japanese_text, interleaved: true) do
      # The source text, not the model's echo of it, is what the translation is
      # aligned against — a line the model drops or alters can then only affect
      # its own line rather than the parity of the whole page.
      json =
        Json.format_to_translation_json(interleaved_translation, japanese_text,
          label: "#{page.story} page #{page.number}"
        )

      Page.update_translation(page, json)

      page |> Japanese.Events.Page.translation_finished()

      case Story.get_by_name(page.story) do
        {:ok, story} -> story |> Japanese.Events.Story.pages_updated()
        _ -> :ok
      end

      :ok
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defdelegate translate_page_async(page), to: Japanese.Translation.Service, as: :translate_page

  @doc """
  Returns the Anthropic model id to use for the given operation.

  Configurable via `config :japanese, Japanese.Translation, model: "..."` (a
  shared default) and/or
  `models: %{ja_to_en: "...", en_to_ja: "...", explain: "...", reading: "..."}`
  (a per-operation override). A per-operation entry wins over the shared
  `:model`, which itself falls back to #{inspect(@default_model)} if unset.

  `:reading` is the on-demand hiragana reading lookup (see `reading_for/2`) —
  a few tokens of output, so a cheaper/faster model is a reasonable override
  even when the other operations stay on the shared default.
  """
  @spec model(:ja_to_en | :en_to_ja | :explain | :reading) :: String.t()
  def model(operation) when operation in [:ja_to_en, :en_to_ja, :explain, :reading] do
    config = Application.get_env(:japanese, __MODULE__, [])
    models = Keyword.get(config, :models, %{})

    Map.get(models, operation) || Keyword.get(config, :model, @default_model)
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

    interleaved_part =
      if interleaved do
        " " <> File.read!(Application.app_dir(:japanese, "priv/translation/interleave.txt"))
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
    api_key = Application.fetch_env!(:japanese, __MODULE__)[:api_key]

    if is_nil(api_key) do
      raise "ANTHROPIC_API_KEY is not set in config or environment"
    end

    Anthropix.init(api_key, receive_timeout: 600_000)
  end

  defp call_anthropix(system_prompt, user_text, operation, opts \\ []) do
    client = build_client()
    retry = Keyword.get(opts, :retries, 3)
    max_tokens = Keyword.get(opts, :max_tokens, 16_384)

    Anthropix.chat(
      client,
      model: model(operation),
      messages: [
        %{role: "user", content: user_text}
      ],
      system: system_prompt,
      max_tokens: max_tokens
    )
    |> case do
      {:ok, anthropix_result} ->
        Response.parse_response(anthropix_result)

      {:error, %Req.TransportError{reason: :closed}} = error ->
        if retry > 0 do
          call_anthropix(
            system_prompt,
            user_text,
            operation,
            Keyword.put(opts, :retries, retry - 1)
          )
        else
          error
        end

      {:error, err} ->
        {:error, err}
    end
  end

  defp check_stop_reason("end_turn", _response, _operation), do: :ok
  defp check_stop_reason(nil, _response, _operation), do: :ok

  defp check_stop_reason(stop_reason, response, operation) do
    Logger.metadata(model: response.model)

    Logger.warning("""
    Translation stopped without finishing naturally.
    Operation: #{operation}
    Stop reason: #{stop_reason}
    Model: #{response.model}
    Usage: #{inspect(response.usage)}
    Text length: #{String.length(List.first(response.content).text)} characters
    """)
  end

  defp handle_response(
         {:ok,
          %{content: [%{text: text} | _], usage: usage, stop_reason: stop_reason} = response},
         :ja_to_en
       ) do
    check_stop_reason(stop_reason, response, :ja_to_en)
    %__MODULE__{text: text, usage: usage}
  end

  defp handle_response(
         {:ok, %{content: [%{text: text} | _], stop_reason: stop_reason} = response},
         :en_to_ja
       )
       when is_binary(text) do
    check_stop_reason(stop_reason, response, :en_to_ja)
    %{text: text}
  end

  defp handle_response(
         {:ok, %{content: [%{text: text} | _], stop_reason: stop_reason} = response},
         :explain
       )
       when is_binary(text) do
    check_stop_reason(stop_reason, response, :explain)
    text
  end

  defp handle_response(
         {:ok, %{content: [%{text: text} | _], stop_reason: stop_reason} = response},
         :reading
       )
       when is_binary(text) do
    check_stop_reason(stop_reason, response, :reading)

    case stop_reason do
      "max_tokens" -> {:error, :truncated}
      _ -> String.trim(text)
    end
  end

  defp handle_response({:ok, %{content: []}}, _),
    do: {:error, :no_content}

  defp handle_response({:ok, %{content: _messages}}, _),
    do: {:error, :multiple_messages}

  defp handle_response({:error, err}, _),
    do: {:error, err}
end
