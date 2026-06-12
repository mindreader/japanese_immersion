defmodule Japanese.Drill do
  @moduledoc """
  High-level entry point for the verb conjugation drill.

  For interactive exploration, call `sample/0` in IEx to see a random verb in
  a random form, pretty-printed with the kanji form, English meaning, form
  description, example, and every other (verb, form) pair that produces the
  same kana string (the ambiguity reveal).
  """

  alias Japanese.Drill.{Conjugator, Verbs, Verb}

  @type prompt :: %{
          prompt: String.t(),
          verb: Verb.t(),
          form: atom(),
          kanji: String.t(),
          help: map(),
          matches: [{Verb.t(), atom()}]
        }

  @doc """
  Pick a uniformly random verb × form and pretty-print it to the console.
  Returns `:ok`. For the underlying data, call `random/0` instead.
  """
  @spec sample() :: :ok
  def sample, do: random() |> pretty()

  @doc "Random verb × form, returned as the prompt struct."
  @spec random() :: prompt()
  def random do
    verb = Enum.random(Verbs.all())
    form = Enum.random(Conjugator.forms())
    present(verb, form)
  end

  @doc """
  Build the full prompt + reveal data for a specific (verb, form). The
  `matches` field lists every (verb, form) pair across the whole verb set
  whose kana form is identical to this one — that's the disambiguation
  reveal shown on the drill card.
  """
  @spec present(Verb.t(), atom()) :: prompt()
  def present(verb, form) do
    {kanji, kana} = Conjugator.conjugate(verb, form)

    %{
      prompt: kana,
      verb: verb,
      form: form,
      kanji: kanji,
      help: Conjugator.help(form),
      matches: matches_for(kana)
    }
  end

  @doc """
  Every (verb, form) pair in the verb list whose kana conjugation equals
  `kana_form`. This is what powers the "could be..." reveal.
  """
  @spec matches_for(String.t()) :: [{Verb.t(), atom()}]
  def matches_for(kana_form) do
    forms = Conjugator.forms()

    for verb <- Verbs.all(), form <- forms, reduce: [] do
      acc ->
        case Conjugator.conjugate(verb, form) do
          {_, ^kana_form} -> [{verb, form} | acc]
          _ -> acc
        end
    end
    |> Enum.reverse()
  end

  @doc "Pretty-print a prompt struct to the console."
  @spec pretty(prompt()) :: :ok
  def pretty(p) do
    IO.puts("")
    IO.puts("  Prompt:  #{p.prompt}")
    IO.puts("")
    IO.puts("  Form:         #{p.help.label}")
    IO.puts("  Description:  #{p.help.description}")
    IO.puts("  Example:      #{p.help.example}")
    IO.puts("")
    IO.puts("  Could be:")

    for {v, f} <- p.matches do
      kanji_disp = if v.kanji, do: "#{v.kanji} / #{v.kana}", else: v.kana
      form_label = Conjugator.help(f).label
      IO.puts("    • #{kanji_disp}  —  #{v.english}  (#{v.class}, #{form_label})")
    end

    IO.puts("")
    :ok
  end
end
