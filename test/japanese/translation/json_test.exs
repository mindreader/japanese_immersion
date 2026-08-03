defmodule Test.Japanese.Translation.Json do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias Japanese.Translation.Json
  alias Test.Fixtures.OldTranslation

  @moduletag :capture_log

  # A real page has leading ideographic spaces, 「」 quotes and full-width digits.
  # Fixtures made of foo/bar are how a pairing bug ships unnoticed. Single blank
  # lines only, so this page has no paragraph breaks to reason about.
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
               %{"paragraph_break" => true},
               %{"japanese" => "「いらっしゃいますか！！」", "english" => "\"Are you there!!\""},
               %{"paragraph_break" => true},
               %{"japanese" => "大きな声が聞こえてくる。", "english" => "I hear loud voices."},
               %{"paragraph_break" => true},
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

          assert entries(json)
                 |> Enum.reject(& &1["paragraph_break"])
                 |> Enum.map(& &1["english"]) ==
                   [
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
  end

  # The paragraph shape of a page is a property of its source text, not of the
  # reply: one blank line separates lines, a run of two or more is a break.
  describe "paragraph breaks read off the source text" do
    test "a single blank line between two lines is not a paragraph break" do
      json =
        ["1\tVisitor ②", "2\tI hear loud voices."]
        |> reply()
        |> Json.format_to_translation_json("来訪者　②\n\n　大きな声が聞こえてくる。\n")

      assert entries(json) == [
               %{"japanese" => "来訪者　②", "english" => "Visitor ②"},
               %{"japanese" => "大きな声が聞こえてくる。", "english" => "I hear loud voices."}
             ]
    end

    test "a run of two blank lines is exactly one paragraph break" do
      json =
        ["1\tVisitor ②", "2\tI hear loud voices."]
        |> reply()
        |> Json.format_to_translation_json("来訪者　②\n\n\n　大きな声が聞こえてくる。\n")

      assert entries(json) == [
               %{"japanese" => "来訪者　②", "english" => "Visitor ②"},
               %{"paragraph_break" => true},
               %{"japanese" => "大きな声が聞こえてくる。", "english" => "I hear loud voices."}
             ]
    end

    test "a run of five blank lines is still exactly one paragraph break" do
      json =
        ["1\tVisitor ②", "2\tI hear loud voices."]
        |> reply()
        |> Json.format_to_translation_json("来訪者　②\n\n\n\n\n\n　大きな声が聞こえてくる。\n")

      assert Enum.count(entries(json), & &1["paragraph_break"]) == 1
    end

    test "a blank run at the top of the page is not a break above the first line" do
      json =
        ["1\tVisitor ②"]
        |> reply()
        |> Json.format_to_translation_json("\n\n\n来訪者　②\n")

      assert entries(json) == [%{"japanese" => "来訪者　②", "english" => "Visitor ②"}]
    end

    test "a blank run at the end of the page is not a break after the last line" do
      json =
        ["1\tVisitor ②"]
        |> reply()
        |> Json.format_to_translation_json("来訪者　②\n\n\n\n")

      assert entries(json) == [%{"japanese" => "来訪者　②", "english" => "Visitor ②"}]
    end

    test "a page of one line and no blank runs has no breaks" do
      json = Json.format_to_translation_json("1\tVisitor ②", "来訪者　②")

      assert entries(json) == [%{"japanese" => "来訪者　②", "english" => "Visitor ②"}]
    end

    test "a source of nothing but blank lines yields an empty page" do
      json = Json.format_to_translation_json("", "\n\n\n\n")

      assert entries(json) == []
    end

    test "a scene marker in the reply cannot add a break the source does not have" do
      json =
        ["1\tVisitor ②", "!CONTINUED!\t2", "2\tI hear loud voices."]
        |> reply()
        |> Json.format_to_translation_json("来訪者　②\n\n　大きな声が聞こえてくる。\n")

      assert entries(json) == [
               %{"japanese" => "来訪者　②", "english" => "Visitor ②"},
               %{"japanese" => "大きな声が聞こえてくる。", "english" => "I hear loud voices."}
             ]
    end

    test "a scene marker in the reply cannot move a break the source does have" do
      json =
        ["!CONTINUED!", "1\tVisitor ②", "2\tI hear loud voices."]
        |> reply()
        |> Json.format_to_translation_json("来訪者　②\n\n\n　大きな声が聞こえてくる。\n")

      assert entries(json) == [
               %{"japanese" => "来訪者　②", "english" => "Visitor ②"},
               %{"paragraph_break" => true},
               %{"japanese" => "大きな声が聞こえてくる。", "english" => "I hear loud voices."}
             ]
    end
  end

  # 「、、、、、」 is a character trailing off into silence. It carries no kana and no
  # kanji, so a script test calls it a separator glyph and drops it — taking its
  # translation with it and unpairing everything after it. It is real dialogue,
  # it is in the source, and one line like it lives in a real production page.
  describe "a line of punctuation that is real dialogue" do
    @silence "「、、、、、」"
    @silence_page "　男は答えなかった。\n\n#{@silence}\n\n　私は待った。\n"

    test "keeps its translation when the reply is indexed" do
      json =
        ["1\tThe man did not answer.", "2\t\".....\"", "3\tI waited."]
        |> reply()
        |> Json.format_to_translation_json(@silence_page)

      assert entries(json) == [
               %{"japanese" => "男は答えなかった。", "english" => "The man did not answer."},
               %{"japanese" => @silence, "english" => "\".....\""},
               %{"japanese" => "私は待った。", "english" => "I waited."}
             ]
    end

    test "keeps its translation when the model echoes the Japanese back" do
      json =
        [
          "　男は答えなかった。",
          "The man did not answer.",
          @silence,
          "\".....\"",
          "　私は待った。",
          "I waited."
        ]
        |> reply()
        |> Json.format_to_translation_json(@silence_page)

      assert entries(json) == [
               %{"japanese" => "男は答えなかった。", "english" => "The man did not answer."},
               %{"japanese" => @silence, "english" => "\".....\""},
               %{"japanese" => "私は待った。", "english" => "I waited."}
             ]
    end

    test "is content, not a separator, with no source text to consult" do
      json =
        [@silence, "\".....\"", "　私は待った。", "I waited."]
        |> reply()
        |> Json.format_to_translation_json()

      assert entries(json) == [
               %{"japanese" => @silence, "english" => "\".....\""},
               %{"japanese" => "私は待った。", "english" => "I waited."}
             ]
    end

    test "stays paired even when the model leaves it untranslated" do
      json =
        ["1\tThe man did not answer.", "3\tI waited."]
        |> reply()
        |> Json.format_to_translation_json(@silence_page)

      assert entries(json) == [
               %{"japanese" => "男は答えなかった。", "english" => "The man did not answer."},
               %{"japanese" => @silence, "english" => nil},
               %{"japanese" => "私は待った。", "english" => "I waited."}
             ]
    end
  end

  # The bug this module exists to kill was a cascade: one wrong line unpaired
  # every line after it. The invariant that makes a cascade impossible is that a
  # page has one entry per source line whatever the reply looks like, so damage
  # can only ever be as wide as the lines that were actually mistranslated.
  describe "several kinds of drift in one reply" do
    @page_lines [
      "来訪者　②",
      "「『救国の乙女』様」",
      "「いらっしゃいますか！！」",
      "大きな声が聞こえてくる。",
      "「、、、、、」",
      "私の事を『救国の乙女』と呼ぶ彼らは、私の名前なんて覚えていないのかもしれない。",
      "そんなことを思いながら私は扉を開けた。",
      "扉の外には見知らぬ男が立っていた。"
    ]

    @page_englishes [
      "Visitor ②",
      "\"'Maiden of National Salvation'-sama\"",
      "\"Are you there!!\"",
      "I hear loud voices.",
      "\".....\"",
      "Those who call me the 'Maiden of National Salvation' might not remember my name.",
      "While thinking such things, I opened the door.",
      "A man I did not know was standing outside the door."
    ]

    # Two blank lines after line 4, one blank line everywhere else: one break.
    @page (@page_lines
           |> Enum.with_index(1)
           |> Enum.map(fn
             {line, 4} -> "　#{line}\n"
             {line, _n} -> "　#{line}"
           end)
           |> Enum.join("\n\n")) <> "\n"

    test "leaves the whole page paired when the model omits, merges, splits, repeats and reorders" do
      reply =
        [
          "8\t#{Enum.at(@page_englishes, 7)}",
          "6\t#{Enum.at(@page_englishes, 5)}",
          "5\t#{Enum.at(@page_englishes, 4)}",
          # merged 3 into 2, so 3 never comes back on its own
          "2\t#{Enum.at(@page_englishes, 1)} #{Enum.at(@page_englishes, 2)}",
          # split across two lines, the second unnumbered
          "7\tWhile thinking such things,",
          "I opened the door.",
          # sent twice
          "1\t#{Enum.at(@page_englishes, 0)}",
          "1\t#{Enum.at(@page_englishes, 0)}"
          # line 4 omitted entirely
        ]
        |> reply()
        |> Json.format_to_translation_json(@page)

      assert entries(reply) == [
               %{"japanese" => Enum.at(@page_lines, 0), "english" => Enum.at(@page_englishes, 0)},
               %{
                 "japanese" => Enum.at(@page_lines, 1),
                 "english" => "#{Enum.at(@page_englishes, 1)} #{Enum.at(@page_englishes, 2)}"
               },
               %{"japanese" => Enum.at(@page_lines, 2), "english" => nil},
               %{"japanese" => Enum.at(@page_lines, 3), "english" => nil},
               %{"paragraph_break" => true},
               %{"japanese" => Enum.at(@page_lines, 4), "english" => Enum.at(@page_englishes, 4)},
               %{"japanese" => Enum.at(@page_lines, 5), "english" => Enum.at(@page_englishes, 5)},
               %{
                 "japanese" => Enum.at(@page_lines, 6),
                 "english" => "While thinking such things, I opened the door."
               },
               %{"japanese" => Enum.at(@page_lines, 7), "english" => Enum.at(@page_englishes, 7)}
             ]
    end

    test "keeps every source line in its own entry when the model echoes with no indices at all" do
      reply =
        @page_lines
        |> Enum.zip(@page_englishes)
        |> Enum.flat_map(fn {japanese, english} -> ["　#{japanese}", english] end)
        |> reply()
        |> Json.format_to_translation_json(@page)

      pairs = Enum.reject(entries(reply), & &1["paragraph_break"])

      assert Enum.map(pairs, & &1["japanese"]) == @page_lines
      assert Enum.map(pairs, & &1["english"]) == @page_englishes
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

    # Pretty printing is a per-environment setting, so the corpus holds both
    # styles: production files are one minified line with no trailing newline.
    test "decodes a minified production file the same as an indented one" do
      entries = [
        {"来訪者　②", "Visitor ②"},
        :paragraph_break,
        {"大きな声が聞こえてくる。", "I hear loud voices."}
      ]

      assert {:ok, minified} = Json.decode_translation(OldTranslation.minified_page(entries))
      assert {:ok, indented} = Json.decode_translation(OldTranslation.page(entries))

      assert minified == indented

      assert minified.translation == [
               %{english: "Visitor ②", japanese: "来訪者　②"},
               %{paragraph_break: true},
               %{english: "I hear loud voices.", japanese: "大きな声が聞こえてくる。"}
             ]
    end

    test "does not care what order the keys are written in" do
      japanese_first =
        ~s({"translation":[{"japanese":"来訪者　②","english":"Visitor ②"}],"title":"TODO"})

      english_first =
        ~s({"title":"TODO","translation":[{"english":"Visitor ②","japanese":"来訪者　②"}]})

      assert Json.decode_translation(japanese_first) == Json.decode_translation(english_first)
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
