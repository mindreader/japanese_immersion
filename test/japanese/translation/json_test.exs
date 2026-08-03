defmodule Test.Japanese.Translation.Json do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias Japanese.Translation.Json
  alias Test.Fixtures.OldTranslation

  @moduletag :capture_log

  # A real page has leading ideographic spaces, 「」 quotes and full-width digits.
  # Fixtures made of foo/bar are how a pairing bug ships unnoticed.
  @source """
  来訪者　②


  「『救国の乙女』様」

  「いらっしゃいますか！！」

  　大きな声が聞こえてくる。

  　そんなことを思いながら私は扉を開けた。
  """

  @lines [
    "来訪者　②",
    "「『救国の乙女』様」",
    "「いらっしゃいますか！！」",
    "大きな声が聞こえてくる。",
    "そんなことを思いながら私は扉を開けた。"
  ]

  @englishes [
    "Visitor ②",
    "\"'Maiden of National Salvation'-sama\"",
    "\"Are you there!!\"",
    "I hear loud voices.",
    "While thinking such things, I opened the door."
  ]

  # A page as it sits on disk: unaltered, so lines carry a leading ideographic
  # space and blank runs go to four or five lines. cleanup/1 flattens both before
  # the model ever sees the text, which is why alignment has to clean up too.
  @raw_page "来訪者　②\n\n\n\n\n　「いらっしゃいますか！！」\n\n\n\n　大きな声が聞こえてくる。\n\n\n\n\n　そんなことを思いながら私は扉を開けた。\n"

  defp reply(lines), do: Enum.join(lines, "\n")

  defp entries(json), do: Jason.decode!(json)["translation"]

  defp pair(index),
    do: %{"japanese" => Enum.at(@lines, index), "english" => Enum.at(@englishes, index)}

  defp untranslated(index), do: %{"japanese" => Enum.at(@lines, index), "english" => nil}

  defp indexed_reply(indexes) do
    reply(Enum.map(indexes, &"#{&1 + 1}\t#{Enum.at(@englishes, &1)}"))
  end

  describe "number_source_lines/1" do
    test "numbers non-blank lines from one and keeps blank lines to show paragraph shape" do
      assert Json.number_source_lines("来訪者　②\n\n　大きな声が聞こえてくる。\n") ==
               "1\t来訪者　②\n\n2\t大きな声が聞こえてくる。\n"
    end

    test "numbers the page the same way the file on disk is cleaned up before it is sent" do
      assert Json.number_source_lines(@raw_page) ==
               "1\t来訪者　②\n\n\n2\t「いらっしゃいますか！！」\n\n\n3\t大きな声が聞こえてくる。\n\n\n4\tそんなことを思いながら私は扉を開けた。\n"
    end
  end

  describe "the text on disk versus the text the model saw" do
    test "anchors a page of indented lines and long blank runs by index" do
      json =
        [
          "1\tVisitor ②",
          "2\t\"Are you there!!\"",
          "3\tI hear loud voices.",
          "4\tI opened the door."
        ]
        |> reply()
        |> Json.format_to_translation_json(@raw_page)

      assert entries(json) == [
               %{"japanese" => "来訪者　②", "english" => "Visitor ②"},
               %{"japanese" => "「いらっしゃいますか！！」", "english" => "\"Are you there!!\""},
               %{"japanese" => "大きな声が聞こえてくる。", "english" => "I hear loud voices."},
               %{"japanese" => "そんなことを思いながら私は扉を開けた。", "english" => "I opened the door."}
             ]
    end

    test "anchors indented lines echoed back without their indent, with nothing left unplaced" do
      log =
        capture_log(fn ->
          json =
            [
              "来訪者　②",
              "Visitor ②",
              "「いらっしゃいますか！！」",
              "\"Are you there!!\"",
              "大きな声が聞こえてくる。",
              "I hear loud voices.",
              "そんなことを思いながら私は扉を開けた。",
              "I opened the door."
            ]
            |> reply()
            |> Json.format_to_translation_json(@raw_page)

          assert Enum.map(entries(json), & &1["english"]) == [
                   "Visitor ②",
                   "\"Are you there!!\"",
                   "I hear loud voices.",
                   "I opened the door."
                 ]
        end)

      refute log =~ "[warning]"
    end
  end

  describe "an indexed reply" do
    test "pairs every source line by its number" do
      json = Json.format_to_translation_json(indexed_reply(0..4), @source)

      assert entries(json) == Enum.map(0..4, &pair/1)
    end

    test "places lines by their number even when the model answers out of order" do
      json = Json.format_to_translation_json(indexed_reply([3, 0, 4, 1, 2]), @source)

      assert entries(json) == Enum.map(0..4, &pair/1)
    end

    test "puts a scene break before the line the marker names, wherever it appears in the reply" do
      json =
        ["4\t#{Enum.at(@englishes, 3)}", "!CONTINUED!\t2", "1\t#{Enum.at(@englishes, 0)}"]
        |> reply()
        |> Json.format_to_translation_json(@source)

      assert [
               %{"japanese" => "来訪者　②"},
               %{"paragraph_break" => true},
               %{"japanese" => "「『救国の乙女』様」"} | _rest
             ] = entries(json)
    end

    test "keeps a scene break that names the first line at the top of the page" do
      json =
        (["!CONTINUED!\t1"] ++ Enum.map(0..4, &"#{&1 + 1}\t#{Enum.at(@englishes, &1)}"))
        |> reply()
        |> Json.format_to_translation_json(@source)

      assert [%{"paragraph_break" => true} | rest] = entries(json)
      assert rest == Enum.map(0..4, &pair/1)
    end

    test "keeps an unnumbered scene break at the end of the page" do
      json =
        (Enum.map(0..4, &"#{&1 + 1}\t#{Enum.at(@englishes, &1)}") ++ ["!CONTINUED!"])
        |> reply()
        |> Json.format_to_translation_json(@source)

      assert List.last(entries(json)) == %{"paragraph_break" => true}
      assert length(entries(json)) == 6
    end

    test "keeps the first copy when a line number comes back twice" do
      log =
        capture_log(fn ->
          json =
            ["1\tVisitor ②", "1\tThe visitor, number two", "2\t#{Enum.at(@englishes, 1)}"]
            |> reply()
            |> Json.format_to_translation_json(@source)

          assert Enum.take(entries(json), 2) == [pair(0), pair(1)]
        end)

      assert log =~ "came back twice"
    end

    test "ignores a line number that is not on the page and keeps the rest paired" do
      log =
        capture_log(fn ->
          json =
            [
              "1\t#{Enum.at(@englishes, 0)}",
              "99\tA line from another page",
              "2\t#{Enum.at(@englishes, 1)}"
            ]
            |> reply()
            |> Json.format_to_translation_json(@source)

          assert Enum.take(entries(json), 2) == [pair(0), pair(1)]
        end)

      assert log =~ "past the end of this page"
    end

    test "joins a translation the model wrapped onto an unnumbered second line" do
      json =
        ["1\tVisitor", "②", "2\t#{Enum.at(@englishes, 1)}"]
        |> reply()
        |> Json.format_to_translation_json(@source)

      assert [%{"english" => "Visitor ②"} | _rest] = entries(json)
    end

    test "tolerates the model using a space or a colon instead of a tab" do
      json =
        ["1 #{Enum.at(@englishes, 0)}", "2: #{Enum.at(@englishes, 1)}"]
        |> reply()
        |> Json.format_to_translation_json(@source)

      assert Enum.take(entries(json), 2) == [pair(0), pair(1)]
    end
  end

  describe "a reply that ignores the indexed format" do
    test "keeps a chapter separator the model echoed only once from unpairing the page" do
      source = "来訪者　②\n\n◇◆◇\n\n「いらっしゃいますか！！」\n\n　大きな声が聞こえてくる。\n"

      json =
        [
          "来訪者　②",
          "Visitor ②",
          "◇◆◇",
          "「いらっしゃいますか！！」",
          "\"Are you there!!\"",
          "大きな声が聞こえてくる。",
          "I hear loud voices."
        ]
        |> reply()
        |> Json.format_to_translation_json(source)

      assert entries(json) == [
               %{"japanese" => "来訪者　②", "english" => "Visitor ②"},
               %{"separator" => "◇◆◇"},
               %{"japanese" => "「いらっしゃいますか！！」", "english" => "\"Are you there!!\""},
               %{"japanese" => "大きな声が聞こえてくる。", "english" => "I hear loud voices."}
             ]
    end

    test "loses nothing when the reply has an odd number of lines" do
      json =
        [
          "来訪者　②",
          "Visitor ②",
          "「『救国の乙女』様」",
          "\"'Maiden of National Salvation'-sama\"",
          "「いらっしゃいますか！！」"
        ]
        |> reply()
        |> Json.format_to_translation_json(@source)

      assert entries(json) == [
               pair(0),
               pair(1),
               untranslated(2),
               untranslated(3),
               untranslated(4)
             ]
    end

    test "keeps both halves when the model splits one line into two English sentences" do
      json =
        [
          "大きな声が聞こえてくる。",
          "I hear loud voices.",
          "They are very loud indeed.",
          "そんなことを思いながら私は扉を開けた。",
          "While thinking such things, I opened the door."
        ]
        |> reply()
        |> Json.format_to_translation_json(@source)

      assert Enum.at(entries(json), 3) == %{
               "japanese" => "大きな声が聞こえてくる。",
               "english" => "I hear loud voices. They are very loud indeed."
             }

      assert Enum.at(entries(json), 4) == pair(4)
    end

    test "keeps both halves when the model splits one source line into two echoed lines" do
      source = "――あの時、私はショックだった。悲しくて、苦しくて仕方がなかった。\n"

      json =
        [
          "――あの時、私はショックだった。",
          "――At that time, I was shocked.",
          "悲しくて、苦しくて仕方がなかった。",
          "I was so sad and suffering, I couldn't help it."
        ]
        |> reply()
        |> Json.format_to_translation_json(source)

      assert entries(json) == [
               %{
                 "japanese" => "――あの時、私はショックだった。悲しくて、苦しくて仕方がなかった。",
                 "english" =>
                   "――At that time, I was shocked. I was so sad and suffering, I couldn't help it."
               }
             ]
    end

    test "keeps two entries when the model merges two source lines into one" do
      json =
        [
          "「『救国の乙女』様」「いらっしゃいますか！！」",
          "\"'Maiden of National Salvation'-sama\" \"Are you there!!\"",
          "大きな声が聞こえてくる。",
          "I hear loud voices."
        ]
        |> reply()
        |> Json.format_to_translation_json(@source)

      assert entries(json) == [
               untranslated(0),
               %{
                 "japanese" => "「『救国の乙女』様」",
                 "english" => "\"'Maiden of National Salvation'-sama\" \"Are you there!!\""
               },
               untranslated(2),
               pair(3),
               untranslated(4)
             ]
    end

    test "does not shift the page when the model repeats a line it already translated" do
      json =
        [
          "来訪者　②",
          "Visitor ②",
          "来訪者　②",
          "Visitor ②",
          "「『救国の乙女』様」",
          "\"'Maiden of National Salvation'-sama\"",
          "「いらっしゃいますか！！」",
          "\"Are you there!!\""
        ]
        |> reply()
        |> Json.format_to_translation_json(@source)

      assert entries(json) == [pair(0), pair(1), pair(2), untranslated(3), untranslated(4)]
    end

    test "marks a source line the model skipped as untranslated and pairs the rest correctly" do
      log =
        capture_log(fn ->
          json =
            [
              "来訪者　②",
              "Visitor ②",
              "「いらっしゃいますか！！」",
              "\"Are you there!!\"",
              "大きな声が聞こえてくる。",
              "I hear loud voices."
            ]
            |> reply()
            |> Json.format_to_translation_json(@source, label: "mystory page 5")

          assert entries(json) == [pair(0), untranslated(1), pair(2), pair(3), untranslated(4)]
        end)

      assert log =~ "mystory page 5"
      assert log =~ "came back untranslated"
    end

    test "places echoed lines by their text, not by their position in the reply" do
      json =
        [
          "大きな声が聞こえてくる。",
          "I hear loud voices.",
          "来訪者　②",
          "Visitor ②",
          "「『救国の乙女』様」",
          "\"'Maiden of National Salvation'-sama\""
        ]
        |> reply()
        |> Json.format_to_translation_json(@source)

      assert entries(json) == [pair(0), pair(1), untranslated(2), pair(3), untranslated(4)]
    end

    test "still matches a line whose spacing or full-width forms the model altered" do
      json =
        ["来訪者 ②", "Visitor ②", "　大きな声が聞こえてくる。", "I hear loud voices."]
        |> reply()
        |> Json.format_to_translation_json(@source)

      assert entries(json) == [
               pair(0),
               untranslated(1),
               untranslated(2),
               pair(3),
               untranslated(4)
             ]
    end

    test "still matches a line the model lightly altered" do
      json =
        ["そんなことを思いながら、私は扉を開けたのだ。", "While thinking such things, I opened the door."]
        |> reply()
        |> Json.format_to_translation_json(@source)

      assert Enum.at(entries(json), 4) == pair(4)
    end

    test "falls back to position when the model returns only translations" do
      json =
        @englishes
        |> reply()
        |> Json.format_to_translation_json(@source)

      assert entries(json) == Enum.map(0..4, &pair/1)
    end

    test "puts an unnumbered scene break before the next line it can place" do
      json =
        [
          "来訪者　②",
          "Visitor ②",
          "!CONTINUED!",
          "「『救国の乙女』様」",
          "\"'Maiden of National Salvation'-sama\""
        ]
        |> reply()
        |> Json.format_to_translation_json(@source)

      assert Enum.take(entries(json), 3) == [pair(0), %{"paragraph_break" => true}, pair(1)]
    end
  end

  describe "format_to_translation_json/1 without a source anchor" do
    test "pairs a Japanese line with the English line that follows it" do
      json = Json.format_to_translation_json("こんにちは\nHello")

      assert Jason.decode!(json) == %{
               "title" => "TODO",
               "translation" => [%{"japanese" => "こんにちは", "english" => "Hello"}]
             }
    end

    test "keeps paragraph breaks between pairs" do
      json =
        ["来訪者　②", "Visitor ②", "!CONTINUED!", "大きな声が聞こえてくる。", "I hear loud voices."]
        |> reply()
        |> Json.format_to_translation_json()

      assert entries(json) == [
               %{"japanese" => "来訪者　②", "english" => "Visitor ②"},
               %{"paragraph_break" => true},
               %{"japanese" => "大きな声が聞こえてくる。", "english" => "I hear loud voices."}
             ]
    end

    test "keeps a trailing paragraph break" do
      json =
        ["来訪者　②", "Visitor ②", "!CONTINUED!"]
        |> reply()
        |> Json.format_to_translation_json()

      assert entries(json) == [
               %{"japanese" => "来訪者　②", "english" => "Visitor ②"},
               %{"paragraph_break" => true}
             ]
    end

    test "gives a separator glyph its own entry instead of a pairing slot" do
      json =
        ["来訪者　②", "Visitor ②", "◇◆◇", "大きな声が聞こえてくる。", "I hear loud voices."]
        |> reply()
        |> Json.format_to_translation_json()

      assert entries(json) == [
               %{"japanese" => "来訪者　②", "english" => "Visitor ②"},
               %{"separator" => "◇◆◇"},
               %{"japanese" => "大きな声が聞こえてくる。", "english" => "I hear loud voices."}
             ]
    end

    test "keeps an unpaired trailing Japanese line instead of dropping it" do
      json =
        ["来訪者　②", "Visitor ②", "大きな声が聞こえてくる。"]
        |> reply()
        |> Json.format_to_translation_json()

      assert entries(json) == [
               %{"japanese" => "来訪者　②", "english" => "Visitor ②"},
               %{"japanese" => "大きな声が聞こえてくる。", "english" => nil}
             ]
    end

    test "keeps an English line that has no Japanese to pair with" do
      log =
        capture_log(fn ->
          json =
            ["A stray line.", "来訪者　②", "Visitor ②"]
            |> reply()
            |> Json.format_to_translation_json()

          assert entries(json) == [
                   %{"japanese" => nil, "english" => "A stray line."},
                   %{"japanese" => "来訪者　②", "english" => "Visitor ②"}
                 ]
        end)

      assert log =~ "no Japanese to pair it with"
    end
  end

  describe "decode_translation/1 on the existing corpus" do
    test "decodes a real page written before separators and untranslated lines existed" do
      assert {:ok, decoded} = Json.decode_translation(OldTranslation.page())

      assert decoded.title == "TODO"
      assert length(decoded.translation) == 7

      assert Enum.take(decoded.translation, 3) == [
               %{english: "Visitor ②", japanese: "来訪者　②"},
               %{paragraph_break: true},
               %{
                 english: "\"'Maiden of National Salvation'-sama\"",
                 japanese: "「『救国の乙女』様」"
               }
             ]
    end

    test "decoding an old page logs nothing at all" do
      log =
        capture_log(fn ->
          assert {:ok, _decoded} = Json.decode_translation(OldTranslation.page())
        end)

      assert log == ""
    end

    test "decodes an old page with no paragraph breaks" do
      json =
        OldTranslation.page([
          {"来訪者　②", "Visitor ②"},
          {"大きな声が聞こえてくる。", "I hear loud voices."}
        ])

      assert {:ok, decoded} = Json.decode_translation(json)

      assert decoded.translation == [
               %{english: "Visitor ②", japanese: "来訪者　②"},
               %{english: "I hear loud voices.", japanese: "大きな声が聞こえてくる。"}
             ]
    end

    test "decodes an old page that begins with a paragraph break" do
      json = OldTranslation.page([:paragraph_break, {"来訪者　②", "Visitor ②"}])

      assert {:ok, decoded} = Json.decode_translation(json)
      assert [%{paragraph_break: true}, %{japanese: "来訪者　②"}] = decoded.translation
    end

    test "decodes an old page that ends with a paragraph break" do
      json = OldTranslation.page([{"来訪者　②", "Visitor ②"}, :paragraph_break])

      assert {:ok, decoded} = Json.decode_translation(json)
      assert [%{japanese: "来訪者　②"}, %{paragraph_break: true}] = decoded.translation
    end

    test "decodes a full-length chapter without getting expensive" do
      json = OldTranslation.long_page(200)

      {microseconds, {:ok, decoded}} = :timer.tc(fn -> Json.decode_translation(json) end)

      assert length(decoded.translation) == 200
      assert microseconds < 1_000_000
    end

    test "reports an unknown key once, not once per entry" do
      :persistent_term.erase({Json, :unknown_keys})

      entries = Enum.map(1..50, &%{"japanese" => "来訪者　②", "kana" => "らいほうしゃ#{&1}"})
      json = Jason.encode!(%{"title" => "TODO", "translation" => entries})

      log =
        capture_log(fn ->
          assert {:ok, decoded} = Json.decode_translation(json)
          assert length(decoded.translation) == 50
        end)

      assert log =~ "unknown key"
      assert length(String.split(log, "unknown key")) == 2
    end
  end

  describe "decode_translation/1" do
    test "decodes the entries this module now writes" do
      json =
        ["来訪者　②", "Visitor ②", "◇◆◇", "大きな声が聞こえてくる。"]
        |> reply()
        |> Json.format_to_translation_json()

      assert {:ok, decoded} = Json.decode_translation(json)

      assert decoded.translation == [
               %{japanese: "来訪者　②", english: "Visitor ②"},
               %{separator: "◇◆◇"},
               %{japanese: "大きな声が聞こえてくる。", english: nil}
             ]
    end

    test "keeps reading a file that a newer version wrote with an unknown field" do
      json = """
      {"title": "TODO", "translation": [
        {"japanese": "来訪者　②", "english": "Visitor ②", "furigana": "らいほうしゃ"}
      ]}
      """

      assert {:ok, decoded} = Json.decode_translation(json)

      assert [%{"furigana" => "らいほうしゃ", japanese: "来訪者　②", english: "Visitor ②"}] =
               decoded.translation
    end
  end
end
