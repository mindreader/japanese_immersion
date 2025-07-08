defmodule Test.Japanese.Translation.Json do
  use ExUnit.Case, async: true

  describe "format_to_translation_json/1" do
    test "formats a single Japanese-English pair" do
      input = "こんにちは\nHello"
      json = Japanese.Translation.Json.format_to_translation_json(input)
      assert Jason.decode!(json) == %{
        "title" => "TODO",
        "translation" => [
          %{"japanese" => "こんにちは", "english" => "Hello"}
        ]
      }
    end

    test "formats multiple pairs and paragraph breaks" do
      input = "foo\nbar\n!CONTINUED!\nbaz\nqux"
      json = Japanese.Translation.Json.format_to_translation_json(input)
      assert Jason.decode!(json) == %{
        "title" => "TODO",
        "translation" => [
          %{"japanese" => "foo", "english" => "bar"},
          %{"paragraph_break" => true},
          %{"japanese" => "baz", "english" => "qux"}
        ]
      }
    end

    test "handles trailing paragraph break" do
      input = "foo\nbar\n!CONTINUED!"
      json = Japanese.Translation.Json.format_to_translation_json(input)
      assert Jason.decode!(json) == %{
        "title" => "TODO",
        "translation" => [
          %{"japanese" => "foo", "english" => "bar"},
          %{"paragraph_break" => true}
        ]
      }
    end
  end
end
