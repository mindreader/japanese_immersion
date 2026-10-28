defmodule Japanese.Translation.Screen do
  @moduledoc """
  A local, word-list screen for pages that every model has refused.

  Content filters judge a whole request, so one passage can sink a page. When
  that happens, `Japanese.Translation` asks this module which lines to
  withhold, and resends the page without them. The withheld lines are never
  sent anywhere; they are saved untranslated and read in the Japanese.

  The filters' usual trigger is sexual content involving a minor, so that is
  what the screen looks for: a line is withheld only when a sexual term
  appears near a sign of a minor (an age under 18, or a youth word like 少女).
  Sexual terms between adults, and ages on their own, are left alone.

  Nothing here runs on a page that translated normally: it only runs after a
  refusal, so a false positive costs a few lines of one already-refused page.

  ## The word list

  `priv/translation/screen_terms.txt`, re-read on every run, holds three
  lists (see the file for the format):

    * `[strong]` - unambiguous sexual terms; count within #{8} lines of a minor
    * `[weak]` - words that are sexual only in context (経験, 抱く); count
      within #{3} lines
    * `[youth]` - signs of a minor other than an age

  Ages (`13歳`, `十三才`, `１３歳`) are recognised in code. Matching is a
  plain substring match after NFKC normalisation, so a stem covers its
  conjugations.

  The withheld passage runs from the sexual term to the sign of a minor, plus
  one line either side, since these passages tend to hint across several
  lines rather than spell things out in one.

  `report/0` runs the screen over every page in the corpus, for tuning the
  word list; it prints line numbers only.
  """

  @strong_window 8
  @weak_window 3
  @pad 1
  @adult_age 18

  @age_re ~r/([0-9]+|[〇一二三四五六七八九十]+)\s*[歳才]/u
  @numbered_re ~r/^(\d+)\t(.*)$/u

  @type terms :: %{strong: [String.t()], weak: [String.t()], youth: [String.t()]}

  @doc """
  Screens a numbered page (as from
  `Japanese.Translation.Json.number_source_lines/1`).

  Returns the page with the withheld lines removed (blank lines are kept, so
  the paragraph shape is unchanged) and the withheld line numbers, in order.
  """
  @spec withhold(String.t(), terms()) :: {String.t(), [pos_integer()]}
  def withhold(numbered, terms \\ terms()) when is_binary(numbered) do
    withheld = numbered |> numbered_lines() |> withheld_lines(terms)
    skip = MapSet.new(withheld)

    redacted =
      numbered
      |> String.split("\n")
      |> Enum.reject(fn line ->
        case Regex.run(@numbered_re, line) do
          [_, n, _] -> MapSet.member?(skip, String.to_integer(n))
          nil -> false
        end
      end)
      |> Enum.join("\n")

    {redacted, withheld}
  end

  @doc """
  The numbers of the lines to withhold from `[{number, text}]`, in order.
  """
  @spec withheld_lines([{pos_integer(), String.t()}], terms()) :: [pos_integer()]
  def withheld_lines(lines, terms \\ terms()) do
    texts = Enum.map(lines, fn {_n, text} -> normalize(text) end)
    numbers = lines |> Enum.map(&elem(&1, 0)) |> List.to_tuple()
    indexed = Enum.with_index(texts)

    minors = for {text, i} <- indexed, minor?(text, terms.youth), do: i
    strong = for {text, i} <- indexed, contains_any?(text, terms.strong), do: i
    weak = for {text, i} <- indexed, contains_any?(text, terms.weak), do: i
    last = tuple_size(numbers) - 1

    (spans(strong, minors, @strong_window) ++ spans(weak, minors, @weak_window))
    |> Enum.flat_map(fn {from, to} -> Enum.to_list(max(from - @pad, 0)..min(to + @pad, last)) end)
    |> Enum.uniq()
    |> Enum.sort()
    |> Enum.map(&elem(numbers, &1))
  end

  @doc """
  The ages stated in a line (`13歳`, `十三才`, `１３歳`), as integers.
  """
  @spec ages(String.t()) :: [non_neg_integer()]
  def ages(text) do
    for [_, number] <- Regex.scan(@age_re, normalize(text)),
        age = parse_number(number),
        is_integer(age),
        do: age
  end

  @doc """
  Formats line numbers as ranges for logs: `[3, 4, 5, 9]` -> `"3-5, 9"`.
  """
  @spec format_ranges([pos_integer()]) :: String.t()
  def format_ranges(numbers) do
    numbers
    |> Enum.sort()
    |> Enum.chunk_while(
      [],
      fn
        n, [prev | _] = acc when n == prev + 1 -> {:cont, [n | acc]}
        n, [] -> {:cont, [n]}
        n, acc -> {:cont, Enum.reverse(acc), [n]}
      end,
      fn
        [] -> {:cont, []}
        acc -> {:cont, Enum.reverse(acc), []}
      end
    )
    |> Enum.map_join(", ", fn
      [n] -> "#{n}"
      run -> "#{List.first(run)}-#{List.last(run)}"
    end)
  end

  @doc """
  Loads the word list from `priv/translation/screen_terms.txt`.
  """
  @spec terms() :: terms()
  def terms do
    :japanese
    |> Application.app_dir("priv/translation/screen_terms.txt")
    |> File.read!()
    |> parse_terms()
  end

  @doc """
  Parses the word-list format: `[strong]`, `[weak]` and `[youth]` sections,
  one term per line, `#` comments.
  """
  @spec parse_terms(String.t()) :: terms()
  def parse_terms(text) do
    text
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == "" or String.starts_with?(&1, "#")))
    |> Enum.reduce({nil, %{strong: [], weak: [], youth: []}}, fn
      "[strong]", {_, acc} -> {:strong, acc}
      "[weak]", {_, acc} -> {:weak, acc}
      "[youth]", {_, acc} -> {:youth, acc}
      "[" <> _ = section, _ -> raise ArgumentError, "unknown section #{section} in screen terms"
      _term, {nil, _} -> raise ArgumentError, "screen term outside a section"
      term, {section, acc} -> {section, Map.update!(acc, section, &[normalize(term) | &1])}
    end)
    |> elem(1)
  end

  @doc """
  Runs the screen over every page in the corpus and prints, for each page it
  would withhold lines from, the page and the line numbers (no text). Returns
  `%{pages: total, flagged: [{story, page, [line_number]}]}`.

  For tuning the word list. On a release:
  `bin/japanese eval "Japanese.Translation.Screen.report()"`.
  """
  @spec report() :: %{pages: non_neg_integer(), flagged: [{String.t(), integer(), [integer()]}]}
  def report do
    alias Japanese.Corpus.{Page, Story}

    terms = terms()

    pages =
      for story <- Japanese.Corpus.list_stories(),
          page <- Story.list_pages(story),
          {:ok, text} <- [Page.get_japanese_text(page)],
          do: {story.name, page.number, text}

    flagged =
      for {story, number, text} <- pages,
          {_redacted, withheld} =
            text |> Japanese.Translation.Json.number_source_lines() |> withhold(terms),
          withheld != [] do
        IO.puts("#{story} page #{number}: would withhold lines #{format_ranges(withheld)}")
        {story, number, withheld}
      end

    IO.puts("#{length(flagged)} of #{length(pages)} pages would have lines withheld.")
    %{pages: length(pages), flagged: flagged}
  end

  # [{number, text}] from a numbered page; blank lines carry no number.
  defp numbered_lines(numbered) do
    for line <- String.split(numbered, "\n"),
        [_, n, text] <- [Regex.run(@numbered_re, line)],
        do: {String.to_integer(n), text}
  end

  # {first, last} index spans pairing each sexual-term line with each
  # sign-of-a-minor line within `window` lines of it.
  defp spans(sexual, minors, window) do
    for s <- sexual, m <- minors, abs(s - m) <= window, do: {min(s, m), max(s, m)}
  end

  defp minor?(text, youth_terms) do
    contains_any?(text, youth_terms) or Enum.any?(ages(text), &(&1 < @adult_age))
  end

  defp contains_any?(text, terms), do: Enum.any?(terms, &String.contains?(text, &1))

  defp normalize(text), do: :unicode.characters_to_nfkc_binary(text)

  # Arabic digits, or kanji numerals up to 99 (十三, 二十, 三十五, 七).
  defp parse_number(number) do
    case Integer.parse(number) do
      {n, ""} -> n
      _ -> parse_kanji(number)
    end
  end

  @kanji_digits %{
    "〇" => 0,
    "一" => 1,
    "二" => 2,
    "三" => 3,
    "四" => 4,
    "五" => 5,
    "六" => 6,
    "七" => 7,
    "八" => 8,
    "九" => 9
  }

  defp parse_kanji(number) do
    case String.split(number, "十") do
      [digits] ->
        digits_value(digits)

      [tens, ones] ->
        with t when is_integer(t) <- if(tens == "", do: 1, else: digits_value(tens)),
             o when is_integer(o) <- if(ones == "", do: 0, else: digits_value(ones)) do
          t * 10 + o
        end

      _ ->
        nil
    end
  end

  defp digits_value(digits) do
    digits
    |> String.graphemes()
    |> Enum.reduce_while(0, fn digit, acc ->
      case Map.fetch(@kanji_digits, digit) do
        {:ok, d} -> {:cont, acc * 10 + d}
        :error -> {:halt, nil}
      end
    end)
  end
end
