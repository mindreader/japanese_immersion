defmodule Japanese.Translation.Json do
  @moduledoc """
  Pairs Japanese source lines with their English translations and (de)serialises
  the result as the on-disk translation JSON.

  ## Why this module is defensive

  The translation model is asked to return one English line per Japanese source
  line. It mostly does. When it does not — it echoes a chapter-separator glyph
  once instead of twice, splits a long line into two sentences, merges two short
  lines into one, duplicates a line, or drops one — a parser that infers pairing
  from position alone flips the parity of *every remaining line on the page*.
  That is a rare failure with a total blast radius, which is the worst shape a
  bug can have.

  Three layers guard against it, each a fallback for the one before:

  1. **Classification.** Lines are classified by script (`:japanese`, `:latin`,
     `:separator`) rather than by their position in the reply. A separator glyph
     never consumes a pairing slot, and nothing is silently discarded.

  2. **Source anchoring.** The caller passes the original Japanese, which is the
     authoritative text — the model's echo of it is not. Every entry in the
     output corresponds to exactly one source line, so drift can only ever
     affect the line that drifted. A line the model never translated is written
     with `english: nil` and renders as a visible gap the user can retranslate,
     instead of silently shifting the rest of the page.

  3. **Explicit indices.** The prompt numbers the source lines and asks for
     `<n><TAB><english>` back (see `number_source_lines/1` and
     `priv/translation/interleave.txt`), which makes pairing a lookup rather
     than an inference and makes an omission detectable. Layers 1 and 2 remain
     as the parser for replies that ignore the format — which is exactly the
     scenario this module exists to survive.

  ## Entry shapes

    * `%{japanese: String.t(), english: String.t() | nil}` — a source line and
      its translation. `english: nil` means "not translated", not "empty".
    * `%{separator: String.t()}` — a glyph-only line (`◇◆◇`, `※`, `……`) that is
      structural rather than prose.
    * `%{paragraph_break: true}` — a scene transition.

  Per-entry fields are optional and additive: a future `reading` key belongs
  alongside `japanese`/`english` on a pair entry, where it cannot perturb
  alignment (alignment is keyed on the source line, not on the entry shape).
  """

  require Logger

  # Lenient when reading, strict when writing: we generate "<n>\t<text>" but
  # accept a tab, spaces, or "." / ")" / ":" after the number, so a reply that
  # was 90% right does not fall all the way back to the positional parser.
  @indexed_line ~r/^(\d+)[.):\t ][ \t]*(\S.*)$/u
  @continued_line ~r/^!CONTINUED!(?:[.):\t ][ \t]*(\d+))?\s*$/u

  @japanese_re ~r/[\x{3040}-\x{309F}\x{30A0}-\x{30FF}\x{4E00}-\x{9FFF}]/u
  @latin_re ~r/[A-Za-z]/u

  # How many consecutive source lines the model is assumed capable of merging
  # into a single reply line, and how alike two lines must be to be taken for
  # the same line lightly altered.
  @merge_span 4
  @similarity 0.85

  @type translation_entry ::
          %{
            required(:japanese) => String.t() | nil,
            required(:english) => String.t() | nil,
            optional(atom()) => term()
          }
          | %{separator: String.t()}
          | %{paragraph_break: true}

  @type translation_json :: %{title: String.t(), translation: [translation_entry()]}

  @typep unit :: %{
           index: pos_integer() | nil,
           japanese: String.t() | nil,
           english: String.t() | nil
         }

  @typep report :: :break | {:break, pos_integer()} | {:separator, String.t()} | {:unit, unit()}

  @typep placed ::
           :skip
           | {:break, non_neg_integer() | :unknown}
           | {:unit, non_neg_integer(), String.t() | nil, :indexed | :matched}

  @doc """
  Numbers the non-blank lines of the Japanese text for the prompt.

  The text is cleaned up the same way `format_to_translation_json/3` cleans the
  source it aligns against, so the numbers in the prompt and the source lines the
  reply is matched to are one and the same list. Blank lines are kept, unnumbered,
  so the model can still see paragraph shape.
  """
  @spec number_source_lines(String.t()) :: String.t()
  def number_source_lines(japanese_text) when is_binary(japanese_text) do
    japanese_text
    |> Japanese.Translation.cleanup()
    |> String.split("\n")
    |> Enum.map_reduce(1, fn
      "", number -> {"", number}
      line, number -> {"#{number}\t#{line}", number + 1}
    end)
    |> elem(0)
    |> Enum.join("\n")
  end

  @doc """
  Builds the translation JSON for a page.

  `model_reply` is the raw text the model returned. `source_japanese` is the
  original page text; when given, it is the anchor every entry is built from, so
  the output has exactly one entry per source line no matter what the model did.
  When it is `nil` the reply is parsed on its own (still by script, never by
  parity), which keeps the one-argument form working for callers with no source
  text to hand.

  ## Options

    * `:label` — how to identify this page in warnings, e.g. `"mystory page 5"`.
  """
  @spec format_to_translation_json(String.t(), String.t() | nil, keyword()) :: String.t()
  def format_to_translation_json(model_reply, source_japanese \\ nil, opts \\ [])
      when is_binary(model_reply) do
    label = Keyword.get(opts, :label, "unidentified page")
    reports = parse_reply(model_reply, label)

    translation =
      case source_lines(source_japanese) do
        [] -> unanchored_entries(reports, label)
        sources -> anchored_entries(reports, sources, label)
      end

    %{"title" => "TODO", "translation" => translation}
    |> Jason.encode!(pretty: pretty_json())
  end

  @doc """
  Decodes a translation file into a `t:translation_json/0` map with atom keys.

  Reading is independent of everything else in this module: it needs no source
  text and no model, and it never rewrites the file. Files written before
  separators, untranslated lines or indices existed decode exactly as they
  always did, and an unknown key is kept as a string rather than raising, so a
  file written by a newer version of the app still opens in an older one.
  """
  @spec decode_translation(String.t()) :: {:ok, translation_json()} | {:error, term()}
  def decode_translation(json) do
    json |> Jason.decode(keys: &decode_key/1)
  end

  # The bytes on disk and the bytes the model was shown are not the same: the
  # source is run through `Japanese.Translation.cleanup/1` before it is sent.
  # Anchoring has to see what the model saw, or every line with a leading
  # ideographic space — which is most of them — would fail to match exactly and
  # fall through to the fuzzy end of the ladder for no reason.
  @spec source_lines(String.t() | nil) :: [String.t()]
  defp source_lines(nil), do: []

  defp source_lines(text) do
    text
    |> Japanese.Translation.cleanup()
    |> String.split("\n")
    |> Enum.reject(&(&1 == ""))
  end

  ## Parsing the reply

  @spec parse_reply(String.t(), String.t()) :: [report()]
  defp parse_reply(reply, label) do
    lines =
      reply
      |> String.split("\n")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    if indexed?(lines) do
      Logger.info("Translation pairing (#{label}): reply parsed as indexed.")
      parse_indexed(lines)
    else
      Logger.info("Translation pairing (#{label}): reply carried no indices, parsing by script.")
      parse_interleaved(lines)
    end
  end

  @spec indexed?([String.t()]) :: boolean()
  defp indexed?(lines) do
    case Enum.reject(lines, &Regex.match?(@continued_line, &1)) do
      [] ->
        false

      candidates ->
        Enum.count(candidates, &Regex.match?(@indexed_line, &1)) * 2 >= length(candidates)
    end
  end

  @spec parse_indexed([String.t()]) :: [report()]
  defp parse_indexed(lines) do
    lines
    |> Enum.reduce([], fn line, acc ->
      cond do
        Regex.match?(@continued_line, line) ->
          [continued_report(line) | acc]

        indexed = Regex.run(@indexed_line, line) ->
          [indexed_report(indexed) | acc]

        true ->
          append_to_previous(acc, line)
      end
    end)
    |> Enum.reverse()
  end

  @spec continued_report(String.t()) :: report()
  defp continued_report(line) do
    case Regex.run(@continued_line, line) do
      [_marker, index] -> {:break, String.to_integer(index)}
      _unnumbered -> :break
    end
  end

  @spec indexed_report([String.t()]) :: report()
  defp indexed_report([_line, index, content]) do
    unit = %{index: String.to_integer(index), japanese: nil, english: nil}

    {:unit, put_content(unit, content)}
  end

  # A line with no index of its own continues the previous one — the model wrapped
  # a long translation. With no previous line it is preamble ("Here is the
  # translation:"), and there is nothing else it could sensibly be.
  @spec append_to_previous([report()], String.t()) :: [report()]
  defp append_to_previous([{:unit, unit} | rest], line) do
    [{:unit, put_content(unit, line)} | rest]
  end

  defp append_to_previous(acc, _line), do: acc

  @spec put_content(unit(), String.t()) :: unit()
  defp put_content(unit, content) do
    case classify(content) do
      :japanese -> %{unit | japanese: join_text(unit.japanese, content)}
      _english_or_glyph -> %{unit | english: join_text(unit.english, content)}
    end
  end

  # The fallback parser, for replies that ignore the indexed contract: pair by
  # script, never by parity. A separator glyph becomes its own report instead of
  # consuming a pairing slot, and every English line following a Japanese line
  # belongs to it (the model split one line into two sentences).
  @spec parse_interleaved([String.t()]) :: [report()]
  defp parse_interleaved(lines), do: parse_interleaved(lines, [])

  defp parse_interleaved([], acc), do: Enum.reverse(acc)

  defp parse_interleaved([line | rest], acc) do
    if Regex.match?(@continued_line, line) do
      parse_interleaved(rest, [continued_report(line) | acc])
    else
      parse_classified(classify(line), line, rest, acc)
    end
  end

  @spec parse_classified(:japanese | :latin | :separator, String.t(), [String.t()], [report()]) ::
          [report()]
  defp parse_classified(:japanese, line, rest, acc) do
    {english, rest} = take_english(rest)

    parse_interleaved(rest, [{:unit, %{index: nil, japanese: line, english: english}} | acc])
  end

  defp parse_classified(:latin, line, rest, acc) do
    parse_interleaved(rest, [{:unit, %{index: nil, japanese: nil, english: line}} | acc])
  end

  defp parse_classified(:separator, line, rest, acc) do
    parse_interleaved(rest, [{:separator, line} | acc])
  end

  @spec take_english([String.t()]) :: {String.t() | nil, [String.t()]}
  defp take_english(lines), do: take_english(lines, nil)

  defp take_english([], acc), do: {acc, []}

  defp take_english([line | rest] = lines, acc) do
    if Regex.match?(@continued_line, line) or classify(line) != :latin do
      {acc, lines}
    else
      take_english(rest, join_text(acc, line))
    end
  end

  ## Alignment against the source text

  @spec anchored_entries([report()], [String.t()], String.t()) :: [map()]
  defp anchored_entries(reports, sources, label) do
    state = %{
      claimed: MapSet.new(),
      cursor: -1,
      label: label,
      norms: sources |> Enum.map(&normalise/1) |> List.to_tuple(),
      sources: List.to_tuple(sources)
    }

    {placed, _state} = Enum.map_reduce(reports, state, &place/2)

    assemble(sources, collect_englishes(placed, label), collect_breaks(placed, label), label)
  end

  @spec place(report(), map()) :: {placed(), map()}
  defp place(:break, state), do: {{:break, :unknown}, state}

  defp place({:break, number}, state) do
    if in_range?(number, state) do
      {{:break, number - 1}, state}
    else
      warn(state.label, "scene break points at line #{number}, which is not on this page")
      {:skip, state}
    end
  end

  # Separators are emitted from the source text itself, so the model's echo of
  # one — however many times it echoed it — carries no information.
  defp place({:separator, _glyph}, state), do: {:skip, state}

  defp place({:unit, %{index: number} = unit}, state) when is_integer(number) do
    if in_range?(number, state) do
      index = number - 1

      {{:unit, index, unit.english, :indexed},
       %{state | claimed: MapSet.put(state.claimed, index), cursor: index}}
    else
      warn(state.label, "reply line #{number} is past the end of this page")
      {:skip, state}
    end
  end

  defp place({:unit, unit}, state) do
    case locate(unit, state) do
      [] ->
        warn(state.label, "could not place a translated line, dropping it: #{describe(unit)}")
        {:skip, state}

      indexes ->
        state = %{state | claimed: Enum.into(indexes, state.claimed), cursor: List.last(indexes)}

        {{:unit, hd(indexes), unit.english, :matched}, state}
    end
  end

  @spec in_range?(integer(), map()) :: boolean()
  defp in_range?(number, state), do: number >= 1 and number <= tuple_size(state.sources)

  # No index and no Japanese to match on: the reply is a bare list of
  # translations, so position is the only signal left.
  @spec locate(unit(), map()) :: [non_neg_integer()]
  defp locate(%{japanese: nil}, state) do
    case next_unclaimed(state) do
      nil -> []
      index -> [index]
    end
  end

  # The fallback ladder, cheapest and most certain first.
  defp locate(%{japanese: japanese}, state) do
    normalised = normalise(japanese)

    exact(japanese, state) || same_normalised(normalised, state) ||
      contained(normalised, state) || merged(normalised, state) ||
      similar(normalised, state) || []
  end

  @spec exact(String.t(), map()) :: [non_neg_integer()] | nil
  defp exact(japanese, state) do
    state.sources
    |> indexes_where(&(&1 == japanese))
    |> choose(state)
  end

  @spec same_normalised(String.t(), map()) :: [non_neg_integer()] | nil
  defp same_normalised(normalised, state) do
    state.norms
    |> indexes_where(&(&1 == normalised))
    |> choose(state)
  end

  # The model split one source line into two echoed lines: each half is a
  # substring of the whole. Both halves resolve to the same source line and their
  # translations are joined back up.
  @spec contained(String.t(), map()) :: [non_neg_integer()] | nil
  defp contained("", _state), do: nil

  defp contained(normalised, state) do
    longest = String.length(normalised) * 3

    state.norms
    |> indexes_where(&(String.length(&1) <= longest and String.contains?(&1, normalised)))
    |> choose(state)
  end

  # The model merged consecutive source lines into one. Each source line still
  # gets its own entry; the translation goes to the first of them and the rest
  # are marked untranslated, rather than silently sharing text that is not theirs.
  @spec merged(String.t(), map()) :: [non_neg_integer()] | nil
  defp merged(normalised, state) do
    last = tuple_size(state.norms) - 1

    Enum.find_value(0..last//1, fn start ->
      Enum.find_value(2..@merge_span//1, fn span ->
        indexes = Enum.to_list(start..(start + span - 1)//1)

        if List.last(indexes) <= last and joined_norm(indexes, state) == normalised do
          indexes
        end
      end)
    end)
  end

  # Last resort: the model altered the line rather than echoing it. Take the
  # closest line above the similarity floor, preferring one not yet spoken for.
  @spec similar(String.t(), map()) :: [non_neg_integer()] | nil
  defp similar(normalised, state) do
    state.norms
    |> Tuple.to_list()
    |> Enum.with_index()
    |> Enum.map(fn {norm, index} -> {index, String.jaro_distance(norm, normalised)} end)
    |> Enum.filter(fn {_index, score} -> score >= @similarity end)
    |> case do
      [] ->
        nil

      scored ->
        unclaimed = Enum.reject(scored, fn {index, _} -> MapSet.member?(state.claimed, index) end)
        pool = if unclaimed == [], do: scored, else: unclaimed
        {index, _score} = Enum.max_by(pool, fn {_index, score} -> score end)

        [index]
    end
  end

  @spec joined_norm([non_neg_integer()], map()) :: String.t()
  defp joined_norm(indexes, state) do
    Enum.map_join(indexes, &elem(state.norms, &1))
  end

  @spec indexes_where(tuple(), (String.t() -> boolean())) :: [non_neg_integer()]
  defp indexes_where(values, predicate) do
    values
    |> Tuple.to_list()
    |> Enum.with_index()
    |> Enum.filter(fn {value, _index} -> predicate.(value) end)
    |> Enum.map(fn {_value, index} -> index end)
  end

  # Prefer a line we have not used yet, and among those the first one at or after
  # where we are reading. Falling back to an already-claimed line is what lets a
  # duplicated reply line rejoin the line it belongs to instead of displacing
  # everything after it.
  @spec choose([non_neg_integer()], map()) :: [non_neg_integer()] | nil
  defp choose([], _state), do: nil

  defp choose(indexes, state) do
    unclaimed = Enum.reject(indexes, &MapSet.member?(state.claimed, &1))
    pool = if unclaimed == [], do: indexes, else: unclaimed

    case Enum.filter(pool, &(&1 > state.cursor)) do
      [] -> [Enum.min(pool)]
      forward -> [Enum.min(forward)]
    end
  end

  @spec next_unclaimed(map()) :: non_neg_integer() | nil
  defp next_unclaimed(state) do
    last = tuple_size(state.sources) - 1

    Enum.find((state.cursor + 1)..last//1, &(not MapSet.member?(state.claimed, &1)))
  end

  ## Assembling entries

  @spec collect_englishes([placed()], String.t()) :: %{non_neg_integer() => String.t()}
  defp collect_englishes(placed, label) do
    Enum.reduce(placed, %{}, fn
      {:unit, index, english, origin}, acc when is_binary(english) ->
        merge_english(acc, index, english, origin, label)

      _other, acc ->
        acc
    end)
  end

  @spec merge_english(map(), non_neg_integer(), String.t(), :indexed | :matched, String.t()) ::
          map()
  defp merge_english(acc, index, english, origin, label) do
    case Map.fetch(acc, index) do
      :error ->
        Map.put(acc, index, english)

      {:ok, ^english} ->
        warn(label, "line #{index + 1} came back twice, identically; keeping one copy")
        acc

      {:ok, existing} when origin == :indexed ->
        # The model was told to emit each line number exactly once; a second,
        # differing copy is a duplicate rather than a continuation (continuations
        # arrive as unnumbered lines and are joined while parsing). First wins,
        # loudly — silently taking the last one is how the old bug shipped.
        warn(label, "line #{index + 1} came back twice with different text; keeping the first")
        Map.put(acc, index, existing)

      {:ok, existing} ->
        # Two renderings of one source line: the model split the line and both
        # halves matched it. Joining keeps the whole translation, and can never
        # displace a neighbouring line.
        Map.put(acc, index, join_text(existing, english))
    end
  end

  @spec collect_breaks([placed()], String.t()) :: %{
          before: MapSet.t(non_neg_integer()),
          trailing: boolean()
        }
  defp collect_breaks(placed, label) do
    placed
    |> Enum.reverse()
    |> Enum.reduce({%{before: MapSet.new(), trailing: false}, nil}, fn
      {:break, :unknown}, {breaks, nil} ->
        {%{breaks | trailing: true}, nil}

      {:break, :unknown}, {breaks, next} ->
        warn(label, "scene break carried no line number; placing it before line #{next + 1}")
        {%{breaks | before: MapSet.put(breaks.before, next)}, next}

      {:break, index}, {breaks, next} ->
        {%{breaks | before: MapSet.put(breaks.before, index)}, next}

      {:unit, index, _english, _origin}, {breaks, _next} ->
        {breaks, index}

      :skip, acc ->
        acc
    end)
    |> elem(0)
  end

  @spec assemble([String.t()], map(), map(), String.t()) :: [map()]
  defp assemble(sources, englishes, breaks, label) do
    entries =
      sources
      |> Enum.with_index()
      |> Enum.flat_map(fn {line, index} ->
        entry = source_entry(line, Map.get(englishes, index))

        if MapSet.member?(breaks.before, index), do: [paragraph_break(), entry], else: [entry]
      end)

    log_gaps(sources, englishes, label)

    if breaks.trailing, do: entries ++ [paragraph_break()], else: entries
  end

  @spec source_entry(String.t(), String.t() | nil) :: map()
  defp source_entry(line, english) do
    case classify(line) do
      :separator -> %{"separator" => line}
      _prose -> %{"japanese" => line, "english" => english}
    end
  end

  @spec log_gaps([String.t()], map(), String.t()) :: :ok
  defp log_gaps(sources, englishes, label) do
    missing =
      sources
      |> Enum.with_index()
      |> Enum.count(fn {line, index} ->
        classify(line) != :separator and is_nil(Map.get(englishes, index))
      end)

    if missing > 0 do
      warn(label, "#{missing} of #{length(sources)} lines came back untranslated")
    end

    :ok
  end

  # Without a source anchor we can still refuse to pair by parity: every report
  # becomes exactly one entry and nothing is thrown away.
  @spec unanchored_entries([report()], String.t()) :: [map()]
  defp unanchored_entries(reports, label) do
    Enum.map(reports, fn
      :break ->
        paragraph_break()

      {:break, _number} ->
        paragraph_break()

      {:separator, glyph} ->
        %{"separator" => glyph}

      {:unit, %{japanese: nil, english: english}} ->
        warn(label, "an English line arrived with no Japanese to pair it with: #{english}")
        %{"japanese" => nil, "english" => english}

      {:unit, %{japanese: japanese, english: english}} ->
        %{"japanese" => japanese, "english" => english}
    end)
  end

  @spec paragraph_break() :: map()
  defp paragraph_break, do: %{"paragraph_break" => true}

  ## Text helpers

  @spec classify(String.t()) :: :japanese | :latin | :separator
  defp classify(line) do
    cond do
      Regex.match?(@japanese_re, line) -> :japanese
      Regex.match?(@latin_re, line) -> :latin
      true -> :separator
    end
  end

  # Compatibility normalisation plus whitespace removal: the model routinely
  # drops the leading ideographic space, converts a full-width form, or re-wraps
  # a line, none of which changes which source line it is.
  @spec normalise(String.t()) :: String.t()
  defp normalise(text) do
    text
    |> String.normalize(:nfkc)
    |> String.replace(~r/\s/u, "")
  end

  @spec join_text(String.t() | nil, String.t()) :: String.t()
  defp join_text(nil, text), do: text
  defp join_text(existing, text), do: existing <> " " <> text

  @spec describe(unit()) :: String.t()
  defp describe(%{japanese: nil, english: english}), do: String.slice(english || "", 0, 40)
  defp describe(%{japanese: japanese}), do: String.slice(japanese, 0, 40)

  @spec warn(String.t(), String.t()) :: :ok
  defp warn(label, message), do: Logger.warning("Translation pairing (#{label}): #{message}")

  # Known keys decode to atoms; an unknown key is kept as a string rather than
  # raising. A file written by a newer version of this app (another per-entry
  # field is already planned) must not crash an older reader, and every consumer
  # reads entries through `Map.get/3`, so a stray string key is inert.
  @spec decode_key(String.t()) :: atom() | String.t()
  defp decode_key(key) do
    case key do
      "title" -> :title
      "japanese" -> :japanese
      "english" -> :english
      "translation" -> :translation
      "paragraph_break" -> :paragraph_break
      "separator" -> :separator
      "reading" -> :reading
      other -> unknown_key(other)
    end
  end

  # Reported once per key name for the life of the node: an unknown key usually
  # appears on every entry of every page, and a corpus is hundreds of chapters.
  @spec unknown_key(String.t()) :: String.t()
  defp unknown_key(key) do
    seen = :persistent_term.get({__MODULE__, :unknown_keys}, MapSet.new())

    if not MapSet.member?(seen, key) do
      :persistent_term.put({__MODULE__, :unknown_keys}, MapSet.put(seen, key))

      Logger.warning(
        "#{__MODULE__}: unknown key #{inspect(key)} in a translation file, keeping it"
      )
    end

    key
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
