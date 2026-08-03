defmodule JapaneseWeb.CoreComponents.PageTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias Japanese.Translation.Json
  alias JapaneseWeb.CoreComponents.Page
  alias Test.Fixtures.OldTranslation

  defp render_entries(translation) do
    render_component(&Page.translation/1,
      id: "translation-display",
      content: %{translation: translation}
    )
  end

  test "renders a Japanese line and its translation with the classes the reader toggles on" do
    html = render_entries([%{japanese: "大きな声が聞こえてくる。", english: "I hear loud voices."}])

    assert html =~ "tr-ja"
    assert html =~ "tr-eng"
    assert html =~ "大きな声が聞こえてくる。"
    assert html =~ "I hear loud voices."
  end

  test "marks a line that came back untranslated instead of showing an empty box" do
    html = render_entries([%{japanese: "大きな声が聞こえてくる。", english: nil}])

    assert html =~ "大きな声が聞こえてくる。"
    assert html =~ "not translated"
    # still toggles with the rest of the English
    assert html =~ "tr-eng"
  end

  test "renders a chapter separator as a visible divider rather than a pair" do
    html = render_entries([%{separator: "◇◆◇"}])

    assert html =~ "◇◆◇"
    assert html =~ "tr-sep"
    refute html =~ "tr-eng"
  end

  test "renders a paragraph break as blank space" do
    html = render_entries([%{paragraph_break: true}])

    refute html =~ "tr-ja"
    assert html =~ "height: 1.5em;"
  end

  test "renders a page written before separators existed" do
    html =
      render_entries([
        %{japanese: "来訪者　②", english: "Visitor ②"},
        %{paragraph_break: true},
        %{japanese: "大きな声が聞こえてくる。", english: "I hear loud voices."}
      ])

    assert html =~ "来訪者　②"
    assert html =~ "Visitor ②"
    assert html =~ "大きな声が聞こえてくる。"
    assert html =~ "I hear loud voices."
  end

  describe "a page from the existing corpus" do
    test "a real old-format file renders every line, with nothing marked untranslated" do
      assert {:ok, %{translation: translation}} =
               Json.decode_translation(OldTranslation.page())

      html = render_entries(translation)

      assert html =~ "来訪者　②"
      assert html =~ "Visitor ②"
      assert html =~ "「いらっしゃいますか！！」"
      assert html =~ "While thinking such things, I opened the door."
      assert html =~ "height: 1.5em;"
      refute html =~ "not translated"
      refute html =~ "original line missing"
    end

    test "an old file with no paragraph break at all renders as plain pairs" do
      json = OldTranslation.page([{"来訪者　②", "Visitor ②"}])
      assert {:ok, %{translation: translation}} = Json.decode_translation(json)

      html = render_entries(translation)

      assert html =~ "Visitor ②"
      refute html =~ "height: 1.5em;"
    end

    test "an old file that starts or ends with a paragraph break renders" do
      json =
        OldTranslation.page([:paragraph_break, {"来訪者　②", "Visitor ②"}, :paragraph_break])

      assert {:ok, %{translation: translation}} = Json.decode_translation(json)

      html = render_entries(translation)

      assert html =~ "Visitor ②"
      assert html =~ "height: 1.5em;"
    end

    test "a full-length chapter renders without getting expensive" do
      assert {:ok, %{translation: translation}} =
               Json.decode_translation(OldTranslation.long_page(200))

      {microseconds, html} = :timer.tc(fn -> render_entries(translation) end)

      assert html =~ "This is line 200."
      assert microseconds < 2_000_000
    end
  end

  test "says so when there is no translation at all" do
    html = render_component(&Page.translation/1, id: "translation-display", content: nil)

    assert html =~ "No translation content."
  end
end
