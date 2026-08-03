defmodule Test.Mix.Tasks.Japanese.Corpus.Verify do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  alias Mix.Tasks.Japanese.Corpus.Verify, as: Task
  alias Test.Fixtures.OldTranslation

  defp corpus_dir, do: Briefly.create!(directory: true)

  defp write_page(dir, story, number, japanese, translation) do
    story_dir = Path.join(dir, story)
    File.mkdir_p!(story_dir)
    File.write!(Path.join(story_dir, "#{number}j.txt"), japanese)

    if translation do
      File.write!(Path.join(story_dir, "#{number}tr.yaml"), translation)
    end
  end

  describe "run/1" do
    test "prints a compact summary and exits cleanly when everything decodes" do
      dir = corpus_dir()

      write_page(
        dir,
        "alpha",
        1,
        "来訪者　②",
        OldTranslation.minified_page([{"来訪者　②", "Visitor ②"}])
      )

      output =
        capture_io(fn ->
          Task.run(["--corpus-dir", dir])
        end)

      assert output =~ "Corpus directory: #{dir}"
      assert output =~ "scanned: 1"
      assert output =~ "decoded cleanly: 1"
      assert output =~ "No failures."
      refute output =~ "alpha/1"
    end

    test "--verbose also lists pages that decoded cleanly" do
      dir = corpus_dir()

      write_page(
        dir,
        "alpha",
        1,
        "来訪者　②",
        OldTranslation.minified_page([{"来訪者　②", "Visitor ②"}])
      )

      output =
        capture_io(fn ->
          Task.run(["--corpus-dir", dir, "--verbose"])
        end)

      assert output =~ "alpha/1: ok"
    end

    test "raises (a nonzero exit, at the command line) when a file fails to decode" do
      dir = corpus_dir()
      write_page(dir, "alpha", 1, "来訪者　②", "not json")

      output =
        capture_io(fn ->
          assert_raise Mix.Error, ~r/1 of 1 translation file\(s\) failed to decode/, fn ->
            Task.run(["--corpus-dir", dir])
          end
        end)

      assert output =~ "Failures:"
      assert output =~ "malformed JSON"
    end

    test "never writes to the corpus it scans" do
      dir = corpus_dir()
      translation = OldTranslation.minified_page([{"来訪者　②", "Visitor ②"}])
      write_page(dir, "alpha", 1, "来訪者　②", translation)

      jp_path = Path.join([dir, "alpha", "1j.txt"])
      tr_path = Path.join([dir, "alpha", "1tr.yaml"])
      jp_before = File.read!(jp_path)
      tr_before = File.read!(tr_path)

      capture_io(fn -> Task.run(["--corpus-dir", dir]) end)

      assert File.read!(jp_path) == jp_before
      assert File.read!(tr_path) == tr_before
    end

    test "against the real production sample" do
      dir = corpus_dir()
      story_dir = Path.join(dir, "real")
      File.mkdir_p!(story_dir)
      File.cp!("test/support/fixtures/corpus/98j.txt", Path.join(story_dir, "98j.txt"))
      File.cp!("test/support/fixtures/corpus/98tr.yaml", Path.join(story_dir, "98tr.yaml"))

      output =
        capture_io(fn ->
          Task.run(["--corpus-dir", dir])
        end)

      assert output =~ "scanned: 1"
      assert output =~ "decoded cleanly: 1"
      assert output =~ "No failures."
    end
  end
end
