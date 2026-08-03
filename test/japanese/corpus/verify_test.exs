defmodule Test.Japanese.Corpus.Verify do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias Japanese.Corpus.StorageLayer
  alias Japanese.Corpus.Verify
  alias Test.Fixtures.OldTranslation

  @moduletag :capture_log

  defp corpus_dir do
    Briefly.create!(directory: true)
  end

  defp write_page(dir, story, number, japanese, translation) do
    story_dir = Path.join(dir, story)
    File.mkdir_p!(story_dir)
    File.write!(Path.join(story_dir, "#{number}j.txt"), japanese)

    if translation do
      File.write!(Path.join(story_dir, "#{number}tr.yaml"), translation)
    end
  end

  defp storage(dir), do: %StorageLayer{working_directory: dir}

  describe "run/1 on a corpus with nothing wrong in it" do
    test "reports every translated page as scanned and clean" do
      dir = corpus_dir()

      write_page(
        dir,
        "alpha",
        1,
        "来訪者　②",
        OldTranslation.minified_page([{"来訪者　②", "Visitor ②"}])
      )

      write_page(
        dir,
        "alpha",
        2,
        "大きな声が聞こえてくる。",
        OldTranslation.page([{"大きな声が聞こえてくる。", "I hear loud voices."}])
      )

      report = Verify.run(storage(dir))

      assert report.corpus_dir == dir
      assert report.scanned == 2
      assert report.ok == 2
      assert report.failures == []
    end

    test "does not count an untranslated page as scanned or as a failure" do
      dir = corpus_dir()
      write_page(dir, "alpha", 1, "来訪者　②", nil)

      report = Verify.run(storage(dir))

      assert report.scanned == 0
      assert report.ok == 0
      assert report.failures == []
    end

    test "a story with no pages at all contributes nothing" do
      dir = corpus_dir()
      File.mkdir_p!(Path.join(dir, "empty_story"))

      report = Verify.run(storage(dir))

      assert report.scanned == 0
      assert report.failures == []
    end
  end

  describe "run/1 reports failures without raising" do
    test "a genuinely malformed file is reported, not raised" do
      dir = corpus_dir()
      write_page(dir, "alpha", 1, "来訪者　②", "{not valid json")

      report = Verify.run(storage(dir))

      assert report.scanned == 1
      assert report.ok == 0
      assert [%{story: "alpha", page: 1, status: {:error, reason}}] = report.failures
      assert reason =~ "malformed JSON"
    end

    test "a translation list with a non-map entry is reported, not raised" do
      dir = corpus_dir()
      json = ~s({"title":"TODO","translation":["来訪者　②"]})
      write_page(dir, "alpha", 1, "来訪者　②", json)

      report = Verify.run(storage(dir))

      assert [%{story: "alpha", page: 1, status: {:error, reason}}] = report.failures
      assert reason =~ "not a recognised shape"
    end

    test "a top level with no translation list at all is reported, not raised" do
      dir = corpus_dir()
      json = ~s({"title":"TODO"})
      write_page(dir, "alpha", 1, "来訪者　②", json)

      report = Verify.run(storage(dir))

      assert [%{story: "alpha", page: 1, status: {:error, _reason}}] = report.failures
    end

    test "an unrecognised per-entry key is tolerated: counted clean, and still logged" do
      dir = corpus_dir()

      json =
        ~s({"title":"TODO","translation":[) <>
          ~s({"japanese":"来訪者　②","english":"Visitor ②","compat_verify_marker":"x"}]})

      write_page(dir, "alpha", 1, "来訪者　②", json)

      log =
        capture_log(fn ->
          report = Verify.run(storage(dir))

          assert report.scanned == 1
          assert report.ok == 1
          assert report.failures == []
        end)

      assert log =~ "unknown key"
    end

    test "one bad page among several good ones is the only failure" do
      dir = corpus_dir()

      write_page(
        dir,
        "alpha",
        1,
        "来訪者　②",
        OldTranslation.minified_page([{"来訪者　②", "Visitor ②"}])
      )

      write_page(dir, "alpha", 2, "大きな声が聞こえてくる。", "not json at all")

      report = Verify.run(storage(dir))

      assert report.scanned == 2
      assert report.ok == 1
      assert [%{story: "alpha", page: 2}] = report.failures
    end
  end

  describe "run/1 ordering" do
    test "pages sort numerically, not lexicographically, across the hundreds" do
      dir = corpus_dir()

      for number <- [2, 100, 21] do
        write_page(
          dir,
          "alpha",
          number,
          "来訪者　②",
          OldTranslation.minified_page([{"来訪者　②", "Visitor ②"}])
        )
      end

      report = Verify.run(storage(dir))

      assert Enum.map(report.pages, & &1.page) == [2, 21, 100]
    end

    test "stories sort alphabetically" do
      dir = corpus_dir()

      write_page(
        dir,
        "zeta",
        1,
        "来訪者　②",
        OldTranslation.minified_page([{"来訪者　②", "Visitor ②"}])
      )

      write_page(
        dir,
        "alpha",
        1,
        "来訪者　②",
        OldTranslation.minified_page([{"来訪者　②", "Visitor ②"}])
      )

      report = Verify.run(storage(dir))

      assert Enum.map(report.pages, & &1.story) == ["alpha", "zeta"]
    end
  end

  describe "run/1 against the real production sample" do
    test "the committed real page decodes cleanly" do
      dir = corpus_dir()
      story_dir = Path.join(dir, "real")
      File.mkdir_p!(story_dir)

      File.cp!(
        "test/support/fixtures/corpus/98j.txt",
        Path.join(story_dir, "98j.txt")
      )

      File.cp!(
        "test/support/fixtures/corpus/98tr.yaml",
        Path.join(story_dir, "98tr.yaml")
      )

      report = Verify.run(storage(dir))

      assert report.scanned == 1
      assert report.ok == 1
      assert report.failures == []
    end
  end
end
