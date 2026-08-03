defmodule Test.Japanese.Corpus.Page do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias Japanese.Corpus.Page
  alias JapaneseWeb.CoreComponents.Page, as: PageComponent

  # The only two files anyone has actually measured this pairing rewrite
  # against: a real translated production page, committed verbatim. Every
  # count asserted below (93 pairs, 21 breaks, "TODO" title, the byte-exact
  # source match) was confirmed against these bytes, not against a synthetic
  # fixture — see `test/support/fixtures/old_translation.ex` for the
  # hand-written shapes and this file for the ground truth.
  @fixture_dir "test/support/fixtures/corpus"
  @japanese_file "98j.txt"
  @translation_file "98tr.yaml"

  setup do
    story = "compat_real_corpus_#{System.unique_integer([:positive])}"
    story_dir = Path.join(System.tmp_dir!(), story)
    File.mkdir_p!(story_dir)

    File.cp!(Path.join(@fixture_dir, @japanese_file), Path.join(story_dir, @japanese_file))
    File.cp!(Path.join(@fixture_dir, @translation_file), Path.join(story_dir, @translation_file))

    on_exit(fn -> File.rm_rf(story_dir) end)

    %{story: story, story_dir: story_dir}
  end

  describe "get_translation/1 against the real production sample" do
    test "decodes to the counts already measured against the real files", %{story: story} do
      page = %Page{number: 98, story: story}

      assert {:ok, %{title: "TODO", translation: entries}} = Page.get_translation(page)
      assert length(entries) == 114

      breaks = Enum.count(entries, &match?(%{paragraph_break: true}, &1))
      pairs = Enum.count(entries, &match?(%{japanese: _, english: _}, &1))

      assert breaks == 21
      assert pairs == 93
    end

    test "every pair's japanese text matches a trimmed source line, byte for byte, in order", %{
      story: story
    } do
      page = %Page{number: 98, story: story}

      assert {:ok, source} = Page.get_japanese_text(page)
      assert {:ok, %{translation: entries}} = Page.get_translation(page)

      source_lines =
        source
        |> String.split("\n")
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))

      pair_japanese = for %{japanese: japanese} <- entries, do: japanese

      assert pair_japanese == source_lines
    end

    test "the punctuation-only line of dialogue survives as content, not a stripped separator", %{
      story: story
    } do
      page = %Page{number: 98, story: story}

      assert {:ok, %{translation: entries}} = Page.get_translation(page)

      assert Enum.any?(
               entries,
               &match?(%{japanese: "「、、、、、」", english: "\".....\""}, &1)
             )
    end

    # This is the test that directly encodes the user's requirement: "I don't
    # want to reprocess it ... just making sure the old text still presents."
    # Reading the page and pushing its entries through the render path must
    # leave the files on disk byte-identical — hashed, not just re-parsed, so
    # that whitespace or key-order normalisation could never hide a mutation.
    test "reading and rendering the page leaves both files byte-identical on disk", %{
      story: story,
      story_dir: story_dir
    } do
      page = %Page{number: 98, story: story}
      jp_path = Path.join(story_dir, @japanese_file)
      tr_path = Path.join(story_dir, @translation_file)

      jp_before = File.read!(jp_path)
      tr_before = File.read!(tr_path)
      jp_hash_before = :crypto.hash(:sha256, jp_before)
      tr_hash_before = :crypto.hash(:sha256, tr_before)

      assert {:ok, _text} = Page.get_japanese_text(page)
      assert {:ok, %{translation: entries}} = Page.get_translation(page)

      _html =
        render_component(&PageComponent.translation/1,
          id: "real-corpus-page",
          content: %{translation: entries}
        )

      assert :crypto.hash(:sha256, File.read!(jp_path)) == jp_hash_before
      assert :crypto.hash(:sha256, File.read!(tr_path)) == tr_hash_before
      assert File.read!(jp_path) == jp_before
      assert File.read!(tr_path) == tr_before
    end
  end
end
