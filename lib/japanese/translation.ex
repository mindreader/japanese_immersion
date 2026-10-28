defmodule Japanese.Translation do
  @moduledoc """
  Provides translation functions between Japanese and English using an LLM backend (Anthropic via anthropix).

  This module is also a struct representing a translation result, with fields:
    - :text (the translated text)
    - :usage (the usage struct)
    - :model (the model chain entry that produced it, e.g. "anthropic/claude-sonnet-5-5")

  ## Model chain

  Each operation runs through an ordered chain of `"provider/model"` entries;
  the first one that answers wins. The provider is the first segment and the
  rest is that provider's own model id, so the same model can be listed once
  per provider:

      ["anthropic/claude-sonnet-5-5",            # Anthropic's API directly
       "openrouter/anthropic/claude-sonnet-5.5", # the same model via OpenRouter
       "openrouter/google/gemini-3.8-flash"]     # another vendor entirely

  Providers: `anthropic` (needs `ANTHROPIC_API_KEY`) and `openrouter` (needs
  `OPENROUTER_API_KEY`, see `Japanese.OpenRouter`). An entry whose provider
  has no key is skipped. Note model ids differ between providers (Anthropic's
  `claude-sonnet-5-5` is OpenRouter's `anthropic/claude-sonnet-5.5`).

  Any failure moves on to the next entry: a refusal (Claude's
  `stop_reason: "refusal"`, which sometimes hits perfectly ordinary fiction,
  or another provider's content filter), an outage that outlasts the retries,
  or a timeout. See `chain/1` for configuration and the default.

  ## Pages every model refuses

  Content filters judge a whole request, so one passage can sink a page. When
  every model in the chain refuses a page, it is split at paragraph breaks
  into pieces of about 25 lines, which are translated separately (in
  parallel, against the same time budget) and merged back by line number.
  Lines from a piece that is refused too are saved untranslated
  (`english: nil`) and show as "not translated" on the page. A refused piece
  is not split any further: the aim is to keep the rest of the page, not to
  get the refused passage past a filter.

  A reply that comes back as prose instead of numbered lines (a model saying
  it can't help, rather than refusing outright) counts as a refusal too, so
  the chain moves on rather than saving it as a translation.

  The Anthropic entry uses the unpinned `claude-sonnet-5-5` alias rather than
  a dated snapshot: a dated id is perfectly reproducible but eventually gets
  deprecated and starts hard-failing, while an alias keeps working but means
  behaviour can drift underneath us without a code change. For this app's
  workload (bulk literal translation, judged mainly on faithfulness) we accept
  that drift in exchange for not chasing deprecations.
  """

  require Logger

  # Sonnet first: cheaper than an Opus-class model with a much larger output
  # ceiling and a 1M context, which covers whole-page interleaved translation.
  # Then two other vendors through OpenRouter, so one provider's moderation
  # can't block both. (Listing "openrouter/anthropic/claude-sonnet-5.5" too
  # would cover an Anthropic API outage, but not a refusal: OpenRouter
  # moderates its Anthropic models.)
  @default_chain [
    "anthropic/claude-sonnet-5-5",
    "openrouter/google/gemini-3.8-flash",
    "openrouter/deepseek/deepseek-v4.1-flash"
  ]

  @operations [:ja_to_en, :en_to_ja, :explain, :screenshot]

  # The whole chain must finish inside the async translation ceiling
  # (Japanese.Translation.Service.timeout_ms/0, 240s by default). Each
  # attempt's receive timeout is cut to what is left of this budget, and once
  # one attempt has failed, an entry with under @min_attempt_ms left isn't
  # started. Override with `chain_budget_ms:`.
  @default_chain_budget_ms 220_000
  @min_attempt_ms 20_000

  # Target size, in numbered lines, of the pieces a refused page is split
  # into, and how many are translated at once.
  @piece_lines 25
  @piece_concurrency 4

  # A busy status/equipment screen came to ~1.9k output tokens on Sonnet 5.5
  # and ~3.3k on Sonnet 5 in testing; a dialogue box is far less. 8k leaves
  # room for a dense screen without letting a runaway reply cost much.
  @screenshot_max_tokens 8192

  # How long a single HTTP call to Anthropic may stall before Req gives up and
  # returns `{:error, %Req.TransportError{reason: :timeout}}`. This used to be a
  # flat 10 minutes, which is where the "it started translating and never
  # finished, minutes went by" symptom came from: a stalled request sat here for
  # the full window while the async status stayed pinned at :in_progress. Three
  # minutes is comfortably longer than a healthy whole-page translation takes,
  # and a stall now surfaces as a retryable error fast instead of hanging.
  # Override with `config :japanese, Japanese.Translation, receive_timeout: ms`.
  # It deliberately sits *under* `Japanese.Translation.Service.timeout_ms/0` (the
  # async hard ceiling), so a stalled request fails cleanly on its own before the
  # supervisor has to kill the task out from under it.
  @default_receive_timeout 180_000

  # Transient failures worth another immediate attempt. A connection dropped,
  # reset or refused mid-flight is usually gone by the next try; Anthropic's 5xx
  # and 529 ("overloaded") are load signals that clear on their own, so those
  # retry after a short backoff. A `:timeout` is deliberately NOT retryable: it
  # has already cost the full receive window, and retrying would blow the async
  # time budget instead of promptly surfacing a retryable error to the user.
  @retryable_transport [:closed, :econnrefused, :econnreset, :nxdomain]
  @retryable_status [500, 502, 503, 529]

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

  alias Japanese.OpenRouter
  alias Japanese.Schemas.Anthropic.Response
  alias Japanese.Schemas.Anthropic.Response.{Content, Usage}
  alias Japanese.Translation.Json

  @enforce_keys [:text]
  defstruct [:text, :usage, :model]

  @typedoc "A translation, with the chain entry (`\"provider/model\"`) that produced it."
  @type t :: %__MODULE__{
          text: String.t(),
          usage: Japanese.Schemas.Anthropic.Response.Usage.t(),
          model: String.t() | nil
        }

  @type operation :: :ja_to_en | :en_to_ja | :explain | :screenshot

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
    |> call_llm(text, :ja_to_en)
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
    |> call_llm(text, :en_to_ja)
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
    |> then(&call_llm(system_prompt, &1, :explain))
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

    call_llm(system_prompt, user, :explain)
    |> handle_response(:explain)
  end

  @doc """
  Transcribes a game screenshot into study text: a short description, the
  screen's sections, where the pointer is, and per-line Japanese / hiragana /
  English.

  `ocr_lines` is the Google Vision text of the same image, one line per
  detected paragraph with its pixel box. The model is told the OCR is the
  authority on which characters are present and to use the image only for
  layout, grouping and the cursor — see `priv/games/screenshot.txt`.

  Returns the model's raw reply text (expected to be one JSON object) and the
  chain entry that wrote it, or an error. Parsing and post-processing live in
  `Japanese.Games.Transcript`; a reply cut off by `max_tokens` is reported as
  `{:error, :truncated}` rather than handed on as half a JSON object.
  """
  @spec transcribe_screenshot(binary(), String.t(), String.t()) ::
          {:ok, String.t(), String.t()} | {:error, term()}
  def transcribe_screenshot(image, media_type, ocr_lines)
      when is_binary(image) and is_binary(media_type) and is_binary(ocr_lines) do
    system_prompt = File.read!(Application.app_dir(:japanese, "priv/games/screenshot.txt"))

    content = [
      %{
        type: "image",
        source: %{type: "base64", media_type: media_type, data: Base.encode64(image)}
      },
      %{
        type: "text",
        text: "OCR lines, top to bottom (pixel boxes):\n\n" <> ocr_lines
      }
    ]

    with {:ok, response} <-
           call_llm(system_prompt, content, :screenshot, max_tokens: @screenshot_max_tokens),
         text when is_binary(text) <- handle_response({:ok, response}, :screenshot) do
      {:ok, text, response.model}
    end
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

    label = "#{page.story} page #{page.number}"

    with {:ok, japanese_text} <- Page.get_japanese_text(page),
         {:ok, interleaved_translation} <- translate_page_text(japanese_text, label) do
      # The source text, not the model's echo of it, is what the translation is
      # aligned against — a line the model drops or alters can then only affect
      # its own line rather than the parity of the whole page.
      json =
        Json.format_to_translation_json(interleaved_translation, japanese_text, label: label)

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
  Translates a page's Japanese text into the numbered reply that
  `Japanese.Translation.Json.format_to_translation_json/3` pairs with it.

  The whole page is tried first. If every model refuses it, the page is
  translated in pieces instead (see "Pages every model refuses" in the
  moduledoc): the reply then holds only the lines of the pieces that were
  translated, and the rest are saved untranslated. If every piece is refused
  as well, the whole-page error is returned.
  """
  @spec translate_page_text(String.t(), String.t()) :: {:ok, String.t()} | {:error, term()}
  def translate_page_text(japanese_text, label \\ "unidentified page")
      when is_binary(japanese_text) do
    numbered = Json.number_source_lines(japanese_text)
    deadline = System.monotonic_time(:millisecond) + chain_budget_ms()

    case translate_numbered(numbered, deadline, :whole_page) do
      {:ok, reply} ->
        {:ok, reply}

      {:error, reason} = error ->
        if refused?(reason),
          do: translate_in_pieces(numbered, deadline, label, error),
          else: error
    end
  end

  @doc """
  Whether an error means the content was refused, as opposed to a failure
  (an outage, a timeout) that retrying might fix.
  """
  @spec refused?(term()) :: boolean()
  def refused?(:refused), do: true

  def refused?({:all_models_failed, failures}) when is_list(failures),
    do: failures != [] and Enum.all?(failures, fn {_entry, reason} -> refused?(reason) end)

  def refused?(_reason), do: false

  # One numbered text (a whole page, or a piece of one) through the chain.
  # A reply that is clearly not a translation, typically a model explaining
  # that it won't help, counts as a refusal so the chain moves on:
  #   - a piece is merged by line number, so it needs numbered lines;
  #   - a whole page goes through Json's pairing, which can also handle a
  #     translation that ignored the numbering, so it only has to be roughly
  #     page-sized when it has no numbered lines.
  defp translate_numbered(numbered, deadline, kind) do
    numbers = line_numbers(numbered)

    accept = fn text ->
      cond do
        numbered_reply_lines(text, numbers) != [] -> :ok
        kind == :whole_page and non_blank_lines(text) * 2 >= length(numbers) -> :ok
        true -> {:error, :refused}
      end
    end

    [literalness: :literal, interleaved: true]
    |> build_ja_to_en_prompt()
    |> call_llm(numbered, :ja_to_en, deadline: deadline, accept: accept)
    |> handle_response(:ja_to_en)
    |> case do
      %__MODULE__{text: text} -> {:ok, text}
      {:error, reason} -> {:error, reason}
    end
  end

  defp translate_in_pieces(numbered, deadline, label, whole_page_error) do
    pieces = split_into_pieces(numbered)

    Logger.warning(
      "Every model refused #{label}; translating it in #{length(pieces)} pieces instead."
    )

    results =
      pieces
      |> Task.async_stream(
        fn piece -> {piece, translate_numbered(piece, deadline, :piece)} end,
        max_concurrency: @piece_concurrency,
        timeout: :infinity
      )
      |> Enum.map(fn {:ok, result} -> result end)

    translated =
      for {piece, {:ok, reply}} <- results,
          do: numbered_reply_lines(reply, line_numbers(piece))

    untranslated =
      for {piece, {:error, reason}} <- results do
        numbers = line_numbers(piece)
        "lines #{List.first(numbers)}-#{List.last(numbers)} (#{inspect(reason)})"
      end

    case translated do
      [] ->
        Logger.warning("Every piece of #{label} was refused too.")
        whole_page_error

      _ ->
        if untranslated != [] do
          Logger.warning(
            "#{label}: saved without a translation for " <> Enum.join(untranslated, ", ")
          )
        end

        {:ok, translated |> List.flatten() |> Enum.join("\n")}
    end
  end

  defp non_blank_lines(text),
    do: text |> String.split("\n") |> Enum.count(&(String.trim(&1) != ""))

  # The line numbers in a numbered text ("<n>\t<line>"; blank lines unnumbered).
  defp line_numbers(numbered) do
    for line <- String.split(numbered, "\n"),
        [_, n] <- [Regex.run(~r/^(\d+)\t/, line)],
        do: String.to_integer(n)
  end

  # The reply lines that translate one of `numbers`, normalised to
  # "<n>\t<english>". Anything else (a preamble, an apology, a line number
  # from outside the piece) is dropped, so pieces can't step on each other
  # when they are joined.
  defp numbered_reply_lines(reply, numbers) do
    wanted = MapSet.new(numbers)

    for line <- String.split(reply, "\n"),
        [_, n, english] <- [Regex.run(~r/^\s*(\d+)[.):\t ][ \t]*(\S.*)$/u, line)],
        MapSet.member?(wanted, String.to_integer(n)),
        do: "#{n}\t#{String.trim_trailing(english)}"
  end

  # Splits a numbered page at paragraph breaks into pieces of about
  # @piece_lines numbered lines. A paragraph longer than that is a piece of its
  # own, cut at line boundaries.
  defp split_into_pieces(numbered) do
    numbered
    |> String.split("\n")
    |> Enum.chunk_by(&(&1 == ""))
    |> Enum.reject(&(hd(&1) == ""))
    |> Enum.flat_map(&Enum.chunk_every(&1, @piece_lines))
    |> Enum.chunk_while(
      [],
      fn paragraph, piece ->
        if piece != [] and length(List.flatten(piece)) + length(paragraph) > @piece_lines,
          do: {:cont, Enum.reverse(piece), [paragraph]},
          else: {:cont, [paragraph | piece]}
      end,
      fn
        [] -> {:cont, []}
        piece -> {:cont, Enum.reverse(piece), []}
      end
    )
    |> Enum.map(fn paragraphs -> Enum.map_join(paragraphs, "\n\n", &Enum.join(&1, "\n")) end)
  end

  @doc """
  The model chain for an operation: `"provider/model"` entries, tried in
  order until one answers (see the moduledoc).

      config :japanese, Japanese.Translation,
        # shared by every operation
        chain: ["anthropic/claude-sonnet-5-5", "openrouter/google/gemini-3.8-flash"],
        # per-operation override
        chains: %{explain: ["anthropic/claude-haiku-5"]}

  At runtime these come from environment variables (see `config/runtime.exs`):
  `TRANSLATION_CHAIN` for the shared chain and `TRANSLATION_CHAIN_JA_TO_EN`,
  `_EN_TO_JA`, `_EXPLAIN` or `_SCREENSHOT` for one operation, each a
  comma-separated list:

      TRANSLATION_CHAIN=anthropic/claude-opus-5,openrouter/google/gemini-3.8-flash

  So a string is split on commas (one entry with no commas is a one-entry
  chain), and a `nil`, blank or empty value counts as unset: the operation's
  entry falls back to the shared chain, and that to
  #{inspect(@default_chain)}.

  `:screenshot` (game screenshots, see `transcribe_screenshot/3`) sends an
  image, so its entries need vision-capable models.
  """
  @spec chain(operation()) :: [String.t()]
  def chain(operation) when operation in @operations do
    config = Application.get_env(:japanese, __MODULE__, [])
    chains = Keyword.get(config, :chains) || %{}

    normalize_chain(Map.get(chains, operation)) ||
      normalize_chain(Keyword.get(config, :chain)) ||
      @default_chain
  end

  # A configured chain as a list of entries, or nil when it is unset/empty.
  defp normalize_chain(nil), do: nil

  defp normalize_chain(spec) when is_binary(spec),
    do: spec |> String.split(",") |> normalize_chain()

  defp normalize_chain(specs) when is_list(specs) do
    case specs |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == "")) do
      [] -> nil
      specs -> specs
    end
  end

  @doc """
  Checks every operation's chain, raising `ArgumentError` on a bad entry, and
  returns the chains. Called at startup so a typo in `TRANSLATION_CHAIN`
  stops the app booting instead of failing the first translation.
  """
  @spec validate_chains!() :: %{operation() => [String.t()]}
  def validate_chains! do
    Map.new(@operations, fn operation ->
      chain = chain(operation)
      Enum.each(chain, &parse_spec/1)
      {operation, chain}
    end)
  end

  @doc """
  Splits a chain entry into its provider and that provider's model id.

  Raises `ArgumentError` for an unknown provider or a missing model, so a
  typo in the configuration fails loudly instead of being skipped.
  """
  @spec parse_spec(String.t()) :: {:anthropic | :openrouter, String.t()}
  def parse_spec("anthropic/" <> model) when model != "", do: {:anthropic, model}
  def parse_spec("openrouter/" <> model) when model != "", do: {:openrouter, model}

  def parse_spec(spec) do
    raise ArgumentError,
          "bad model chain entry #{inspect(spec)}: expected \"anthropic/<model>\" or " <>
            "\"openrouter/<vendor>/<model>\""
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

  defp build_client(receive_timeout) do
    api_key = Application.fetch_env!(:japanese, __MODULE__)[:api_key]

    if is_nil(api_key) do
      raise "ANTHROPIC_API_KEY is not set in config or environment"
    end

    # finch: [name: Japanese.Finch] routes through our own pool, which sets
    # conn_max_idle_time (see Japanese.Application). Without it, Anthropix's
    # Req client falls through to Req's shared default pool, whose
    # conn_max_idle_time is :infinity — letting stale keep-alive connections
    # cause phantom request timeouts. (Req 0.7 deprecated the bare
    # `finch: name` form; it still works but warns on every request.)
    #
    # Connection: close keeps Anthropic connections out of the pool
    # altogether: closing a dead idle one inside the pool stalls it for 5s
    # (see Japanese.HTTP).
    Anthropix.init(api_key,
      receive_timeout: receive_timeout,
      finch: [name: Japanese.Finch],
      headers: Japanese.HTTP.no_keepalive_headers()
    )
  end

  # Runs the operation's model chain (see chain/1): each entry in turn until
  # one answers. Returns {:ok, %Response{}} with `model` set to the chain
  # entry that answered, so handle_response/2 doesn't care who it was, or:
  #   - the error itself, when only one entry was tried
  #   - {:all_models_failed, [{entry, reason}, ...]} when several were
  #   - :no_model_available when no entry's provider has an API key
  #
  # Options (besides those passed on to the provider, like :max_tokens):
  #   - :deadline (monotonic ms) shared by several calls; defaults to now plus
  #     the chain budget. No attempt starts with under @min_attempt_ms left.
  #   - :accept, fn reply_text -> :ok | {:error, reason}: a reply it rejects
  #     counts as that entry failing, and the chain moves on.
  defp call_llm(system_prompt, user_content, operation, opts \\ []) do
    entries = operation |> chain() |> Enum.map(&{&1, parse_spec(&1)})
    {deadline, opts} = Keyword.pop(opts, :deadline)
    deadline = deadline || System.monotonic_time(:millisecond) + chain_budget_ms()
    {accept, opts} = Keyword.pop(opts, :accept, fn _text -> :ok end)

    entries
    |> Enum.reduce_while([], fn {spec, target}, failures ->
      left = deadline - System.monotonic_time(:millisecond)

      cond do
        not available?(target) ->
          Logger.info("Skipping #{spec} (#{operation}): no API key for its provider.")
          {:cont, failures}

        left < @min_attempt_ms ->
          Logger.warning("Skipping #{spec} (#{operation}): only #{left}ms of the budget left.")
          {:halt, [{spec, :timeout} | failures]}

        true ->
          timeout = min(left, receive_timeout())

          with {:ok, response} <-
                 attempt(target, system_prompt, user_content, operation, opts, timeout),
               :ok <- accept_reply(response, accept) do
            {:ok, response}
          end
          |> case do
            {:ok, response} ->
              if failures != [] do
                Logger.warning(
                  "#{operation} answered by #{spec} after #{length(failures)} failed " <>
                    "attempt(s): #{inspect(Enum.reverse(failures))}"
                )
              end

              {:halt, {:ok, %{response | model: spec}}}

            {:error, reason} ->
              Logger.warning("#{spec} failed (#{operation}): #{inspect(reason)}")
              {:cont, [{spec, reason} | failures]}
          end
      end
    end)
    |> case do
      {:ok, response} -> {:ok, response}
      [] -> {:error, :no_model_available}
      [{_spec, reason}] -> {:error, reason}
      failures -> {:error, {:all_models_failed, Enum.reverse(failures)}}
    end
  end

  defp accept_reply(response, accept) do
    case first_text(response.content) do
      nil -> :ok
      text -> accept.(text)
    end
  end

  defp available?({:anthropic, _model}) do
    key = Application.get_env(:japanese, __MODULE__, [])[:api_key]
    is_binary(key) and key != ""
  end

  defp available?({:openrouter, _model}), do: OpenRouter.configured?()

  defp attempt({:anthropic, model}, system_prompt, user_content, operation, opts, timeout) do
    opts = opts |> Keyword.put(:model, model) |> Keyword.put(:receive_timeout, timeout)
    call_anthropix(system_prompt, user_content, operation, opts)
  end

  defp attempt({:openrouter, model}, system_prompt, user_content, _operation, opts, timeout) do
    case OpenRouter.chat(model, system_prompt, to_openai_content(user_content),
           max_tokens: Keyword.get(opts, :max_tokens, 16_384),
           receive_timeout: timeout
         ) do
      {:ok, completion} -> {:ok, completion_to_response(completion)}
      {:error, reason} -> {:error, reason}
    end
  end

  # Anthropic content blocks in the OpenAI chat format OpenRouter speaks.
  # Only the two block types this module sends: text and a base64 image.
  defp to_openai_content(text) when is_binary(text), do: text

  defp to_openai_content(blocks) when is_list(blocks) do
    Enum.map(blocks, fn
      %{type: "text", text: text} ->
        %{type: "text", text: text}

      %{type: "image", source: %{type: "base64", media_type: media_type, data: data}} ->
        %{type: "image_url", image_url: %{url: "data:#{media_type};base64,#{data}"}}
    end)
  end

  # An OpenRouter completion in the shape handle_response/2 expects.
  defp completion_to_response(completion) do
    %Response{
      id: nil,
      model: completion.model,
      role: "assistant",
      type: "message",
      stop_reason: if(completion.finish_reason == "length", do: "max_tokens", else: "end_turn"),
      content: [%Content{type: "text", text: completion.text}],
      usage: %Usage{
        input_tokens: completion.usage.input_tokens,
        output_tokens: completion.usage.output_tokens
      }
    }
  end

  defp receive_timeout do
    :japanese
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(:receive_timeout, @default_receive_timeout)
  end

  defp chain_budget_ms do
    :japanese
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(:chain_budget_ms, @default_chain_budget_ms)
  end

  defp log_refusal(raw_response, operation) do
    usage = Map.get(raw_response, "usage") || %{}

    Logger.warning(
      "Claude refused the request. Operation: #{operation}. " <>
        "Model: #{inspect(Map.get(raw_response, "model"))}. " <>
        "Content block types: #{inspect(Enum.map(Map.get(raw_response, "content") || [], &Map.get(&1, "type")))}. " <>
        "Tokens in/out: #{inspect(Map.get(usage, "input_tokens"))}/#{inspect(Map.get(usage, "output_tokens"))}"
    )
  end

  defp call_anthropix(system_prompt, user_text, operation, opts) do
    client = build_client(Keyword.fetch!(opts, :receive_timeout))
    retry = Keyword.get(opts, :retries, 3)
    max_tokens = Keyword.get(opts, :max_tokens, 16_384)

    Anthropix.chat(
      client,
      model: Keyword.fetch!(opts, :model),
      messages: [
        %{role: "user", content: user_text}
      ],
      system: system_prompt,
      max_tokens: max_tokens
    )
    |> case do
      # Checked before validation: a refusal usually has no content at all,
      # which validation would otherwise report as a malformed response.
      # With partial text it is still a failure, not a short translation.
      {:ok, %{"stop_reason" => "refusal"} = anthropix_result} ->
        log_refusal(anthropix_result, operation)
        {:error, :refused}

      {:ok, anthropix_result} ->
        case Response.parse_response(anthropix_result) do
          {:ok, response} ->
            {:ok, response}

          {:error, changeset} ->
            log_invalid_response(changeset, anthropix_result, operation)
            {:error, :invalid_response}
        end

      {:error, error} ->
        if retry > 0 and retryable?(error) do
          Logger.warning(
            "Anthropic call failed (#{operation}), retrying (#{retry} attempt(s) left): " <>
              inspect(error)
          )

          retry_backoff(error)

          call_anthropix(
            system_prompt,
            user_text,
            operation,
            Keyword.put(opts, :retries, retry - 1)
          )
        else
          {:error, error}
        end
    end
  end

  @spec retryable?(term()) :: boolean()
  defp retryable?(%Req.TransportError{reason: reason}), do: reason in @retryable_transport
  defp retryable?(%Anthropix.APIError{status: status}), do: status in @retryable_status
  defp retryable?(_), do: false

  # A connection-level failure is already gone, so retry it straight away; an
  # overloaded/5xx server needs a beat to recover before we ask again.
  @spec retry_backoff(term()) :: :ok
  defp retry_backoff(%Anthropix.APIError{}), do: Process.sleep(1_000)
  defp retry_backoff(_), do: :ok

  # Response validation failing means the raw API payload had some shape we
  # didn't expect (the three known triggers were: a blank text field, a
  # non-text block, or a missing `service_tier`). The caller only ever sees
  # a short `:invalid_response` atom — never this changeset — but the
  # *reason* it failed still needs to be discoverable from the logs,
  # without dumping the whole changeset (which is exactly the "very long
  # difficult to hide error" this exists to prevent). `traverse_errors/2`
  # gives us just the blank/invalid field names instead of the struct.
  defp log_invalid_response(changeset, raw_response, operation) do
    stop_reason = Map.get(raw_response, "stop_reason")

    block_types =
      raw_response
      |> Map.get("content", [])
      |> Enum.map(&Map.get(&1, "type"))

    blank_fields = Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)

    Logger.warning(
      "Anthropic response failed validation. " <>
        "Operation: #{operation}. Stop reason: #{inspect(stop_reason)}. " <>
        "Content block types: #{inspect(block_types)}. Invalid fields: #{inspect(blank_fields)}"
    )
  end

  # Picks the first content block that actually carries usable text,
  # regardless of position. A `thinking` (or any non-text) block ahead of
  # the real answer must not shadow it, and a block with an empty string
  # (an empty-output max_tokens cutoff) doesn't count as text either.
  defp first_text(content) do
    Enum.find_value(content, fn
      %{text: text} when is_binary(text) and text != "" -> text
      _ -> nil
    end)
  end

  defp log_no_usable_text(response, operation) do
    block_types = Enum.map(response.content, & &1.type)

    Logger.warning(
      "Anthropic response had no usable text in any content block. " <>
        "Operation: #{operation}. Stop reason: #{inspect(response.stop_reason)}. " <>
        "Content block types: #{inspect(block_types)}"
    )
  end

  defp check_stop_reason("end_turn", _response, _operation, _text), do: :ok
  defp check_stop_reason(nil, _response, _operation, _text), do: :ok

  defp check_stop_reason(stop_reason, response, operation, text) do
    Logger.metadata(model: response.model)

    Logger.warning("""
    Translation stopped without finishing naturally.
    Operation: #{operation}
    Stop reason: #{stop_reason}
    Model: #{response.model}
    Usage: #{inspect(response.usage)}
    Text length: #{String.length(text)} characters
    """)
  end

  defp handle_response({:ok, response}, :ja_to_en) do
    case first_text(response.content) do
      nil ->
        log_no_usable_text(response, :ja_to_en)
        {:error, :no_usable_text}

      text ->
        check_stop_reason(response.stop_reason, response, :ja_to_en, text)
        %__MODULE__{text: text, usage: response.usage, model: response.model}
    end
  end

  defp handle_response({:ok, response}, :en_to_ja) do
    case first_text(response.content) do
      nil ->
        log_no_usable_text(response, :en_to_ja)
        {:error, :no_usable_text}

      text ->
        check_stop_reason(response.stop_reason, response, :en_to_ja, text)
        %{text: text}
    end
  end

  defp handle_response({:ok, response}, :explain) do
    case first_text(response.content) do
      nil ->
        log_no_usable_text(response, :explain)
        {:error, :no_usable_text}

      text ->
        check_stop_reason(response.stop_reason, response, :explain, text)
        text
    end
  end

  defp handle_response({:ok, response}, :screenshot) do
    case first_text(response.content) do
      nil ->
        log_no_usable_text(response, :screenshot)
        {:error, :no_usable_text}

      text ->
        check_stop_reason(response.stop_reason, response, :screenshot, text)

        case response.stop_reason do
          "max_tokens" -> {:error, :truncated}
          _ -> text
        end
    end
  end

  defp handle_response({:error, err}, _),
    do: {:error, err}
end
