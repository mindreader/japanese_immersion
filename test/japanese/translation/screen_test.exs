defmodule Test.Japanese.Translation.Screen do
  use ExUnit.Case, async: true

  alias Japanese.Translation.Screen

  @terms Screen.parse_terms("""
         # test list
         [strong]
         初体験
         [weak]
         経験
         [youth]
         少女
         """)

  defp lines(texts), do: texts |> Enum.with_index(1) |> Enum.map(fn {t, n} -> {n, t} end)

  defp filler(n), do: List.duplicate("今日はいい天気だ。", n)

  describe "ages/1" do
    test "reads arabic, full-width and kanji ages with 歳 or 才" do
      assert Screen.ages("弟は13歳になった。") == [13]
      assert Screen.ages("弟は１３歳になった。") == [13]
      assert Screen.ages("弟は十三才になった。") == [13]
      assert Screen.ages("父は四十五歳、母は二十歳だ。") == [45, 20]
      assert Screen.ages("七歳の時") == [7]
      assert Screen.ages("彼は天才だ。") == []
      assert Screen.ages("何歳ですか") == []
    end
  end

  describe "withheld_lines/2" do
    test "a weak term near a minor's age withholds the passage plus a line either side" do
      page = filler(5) ++ ["彼は十三歳だ。", "もう経験したのか。"] ++ filler(5)
      assert Screen.withheld_lines(lines(page), @terms) == [5, 6, 7, 8]
    end

    test "a weak term more than 3 lines away doesn't count" do
      page = ["彼は十三歳だ。"] ++ filler(3) ++ ["もう経験したのか。"]
      assert Screen.withheld_lines(lines(page), @terms) == []
    end

    test "a strong term counts up to 8 lines away" do
      page = ["彼は十三歳だ。"] ++ filler(6) ++ ["初体験の話だ。"] ++ filler(3)
      assert Screen.withheld_lines(lines(page), @terms) == Enum.to_list(1..9)
    end

    test "a youth word counts like an age" do
      page = filler(2) ++ ["少女がいた。", "初体験の話だ。"]
      assert Screen.withheld_lines(lines(page), @terms) == [2, 3, 4]
    end

    test "adults, sexual terms alone, and ages alone are left alone" do
      assert Screen.withheld_lines(lines(["彼は二十歳だ。", "初体験の話だ。"]), @terms) == []
      assert Screen.withheld_lines(lines(filler(2) ++ ["初体験の話だ。"]), @terms) == []
      assert Screen.withheld_lines(lines(["彼は十三歳だ。"] ++ filler(2)), @terms) == []
    end

    test "matches after NFKC normalisation" do
      terms = Screen.parse_terms("[strong]\nセックス\n[weak]\n[youth]\n")
      page = ["彼は13歳だ。", "ｾｯｸｽ"]
      assert Screen.withheld_lines(lines(page), terms) == [1, 2]
    end
  end

  describe "withhold/2" do
    test "drops withheld numbered lines and keeps the blank lines" do
      numbered = "1\t今日はいい天気だ。\n\n2\t彼は十三歳だ。\n3\tもう経験したのか。\n\n4\t今日はいい天気だ。"

      assert {redacted, [1, 2, 3, 4]} = Screen.withhold(numbered, @terms)
      assert redacted == "\n"

      numbered = Enum.map_join(1..6, "\n", &"#{&1}\t今日はいい天気だ。") <> "\n7\t彼は十三歳だ。\n8\t経験"
      assert {redacted, [6, 7, 8]} = Screen.withhold(numbered, @terms)
      assert redacted == Enum.map_join(1..5, "\n", &"#{&1}\t今日はいい天気だ。")
    end
  end

  describe "format_ranges/1" do
    test "collapses runs" do
      assert Screen.format_ranges([3, 4, 5, 9, 11, 12]) == "3-5, 9, 11-12"
      assert Screen.format_ranges([]) == ""
    end
  end

  describe "the shipped word list" do
    test "parses, and has all three sections" do
      terms = Screen.terms()
      assert terms.strong != [] and terms.weak != [] and terms.youth != []
    end

    test "rejects unknown sections" do
      assert_raise ArgumentError, fn -> Screen.parse_terms("[mild]\nfoo") end
    end
  end
end
