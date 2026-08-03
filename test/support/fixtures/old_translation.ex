defmodule Test.Fixtures.OldTranslation do
  @moduledoc """
  Translation files in the shape written before source-anchored pairing existed.

  The corpus in production is hundreds of chapters of files exactly like these,
  on a machine this repository cannot see, and it is read-only: it must keep
  rendering without being migrated, rewritten or re-translated. These fixtures
  are the only evidence we can run in CI that it still does, so they mirror a
  real `<n>tr.yaml` byte for byte in shape — keys alphabetised so `english` comes
  first, and nothing but `japanese`, `english` and `paragraph_break`.

  Two on-disk styles are both live, because pretty printing is configured per
  environment: production writes one minified line with no trailing newline,
  development writes it indented. Nothing that reads a file may care which it is
  looking at, so both are represented here.
  """

  @doc """
  A faithful excerpt of a real translated page, verbatim in shape and content.
  """
  @spec page() :: String.t()
  def page do
    """
    {
      "title": "TODO",
      "translation": [
        {
          "english": "Visitor ②",
          "japanese": "来訪者　②"
        },
        {
          "paragraph_break": true
        },
        {
          "english": "\\"'Maiden of National Salvation'-sama\\"",
          "japanese": "「『救国の乙女』様」"
        },
        {
          "english": "\\"Are you there!!\\"",
          "japanese": "「いらっしゃいますか！！」"
        },
        {
          "english": "I hear loud voices.",
          "japanese": "大きな声が聞こえてくる。"
        },
        {
          "english": "Those who call me the 'Maiden of National Salvation' might not even remember my name.",
          "japanese": "私の事を『救国の乙女』と呼ぶ彼らは、もしかしたら私の名前なんて覚えていないのかもしれない。"
        },
        {
          "english": "While thinking such things, I opened the door.",
          "japanese": "そんなことを思いながら私は扉を開けた。"
        }
      ]
    }
    """
  end

  @doc """
  Builds an old-format file from the given entries, in the on-disk shape.

  Pass `:paragraph_break` for a break entry and `{japanese, english}` for a pair.
  """
  @spec page([:paragraph_break | {String.t(), String.t()}]) :: String.t()
  def page(entries) do
    Jason.encode!(%{"title" => "TODO", "translation" => Enum.map(entries, &entry/1)},
      pretty: true
    )
  end

  @doc """
  The same entries in the production style: one minified line, no trailing newline.
  """
  @spec minified_page([:paragraph_break | {String.t(), String.t()}]) :: String.t()
  def minified_page(entries) do
    Jason.encode!(%{"title" => "TODO", "translation" => Enum.map(entries, &entry/1)})
  end

  @doc """
  A page of `count` pairs, for checking that a full-sized chapter stays cheap.
  """
  @spec long_page(pos_integer()) :: String.t()
  def long_page(count) do
    Enum.map(1..count, fn number ->
      {"　#{number}番目の行です。大きな声が聞こえてくる。", "This is line #{number}. I hear loud voices."}
    end)
    |> page()
  end

  defp entry(:paragraph_break), do: %{"paragraph_break" => true}
  defp entry({japanese, english}), do: %{"english" => english, "japanese" => japanese}
end
