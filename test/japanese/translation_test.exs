defmodule Test.Japanese.Translation do
  use ExUnit.Case, async: true
  use Mimic

  alias Japanese.Translation

  setup :verify_on_exit!

  @anthropix_response %{
    "content" => [%{"text" => "これはテストです", "type" => "text"}],
    "id" => "msg_01WWcvFKEMBmjEU2gjnQ5UnJ",
    "model" => "claude-sonnet-4-20250514",
    "role" => "assistant",
    "stop_reason" => "end_turn",
    "stop_sequence" => nil,
    "type" => "message",
    "usage" => %{
      "cache_creation_input_tokens" => 0,
      "cache_read_input_tokens" => 0,
      "input_tokens" => 47,
      "output_tokens" => 5,
      "service_tier" => "standard"
    }
  }

  @anthropix_response_en %{
    "content" => [%{"text" => "This is a test", "type" => "text"}],
    "id" => "msg_01WWcvFKEMBmjEU2gjnQ5UnJ",
    "model" => "claude-sonnet-4-20250514",
    "role" => "assistant",
    "stop_reason" => "end_turn",
    "stop_sequence" => nil,
    "type" => "message",
    "usage" => %{
      "cache_creation_input_tokens" => 0,
      "cache_read_input_tokens" => 0,
      "input_tokens" => 47,
      "output_tokens" => 5,
      "service_tier" => "standard"
    }
  }
  setup do
    Mimic.stub(Anthropix, :chat, fn _client, _opts -> {:error, :llm_error} end)
    :ok
  end

  describe "model/1" do
    setup do
      original = Application.get_env(:japanese, Translation, [])
      on_exit(fn -> Application.put_env(:japanese, Translation, original) end)
      :ok
    end

    test "falls back to the compiled-in default when unset" do
      Application.put_env(:japanese, Translation, api_key: "dummy-key")

      assert Translation.model(:ja_to_en) == "claude-sonnet-5"
      assert Translation.model(:en_to_ja) == "claude-sonnet-5"
      assert Translation.model(:explain) == "claude-sonnet-5"
    end

    test "uses the configured shared :model for every operation" do
      Application.put_env(:japanese, Translation, api_key: "dummy-key", model: "claude-opus-5")

      assert Translation.model(:ja_to_en) == "claude-opus-5"
      assert Translation.model(:en_to_ja) == "claude-opus-5"
      assert Translation.model(:explain) == "claude-opus-5"
    end

    test "a per-operation entry in :models overrides the shared :model" do
      Application.put_env(:japanese, Translation,
        api_key: "dummy-key",
        model: "claude-opus-5",
        models: %{explain: "claude-haiku-5"}
      )

      assert Translation.model(:explain) == "claude-haiku-5"
      assert Translation.model(:ja_to_en) == "claude-opus-5"
      assert Translation.model(:en_to_ja) == "claude-opus-5"
    end

    test "a per-operation entry in :models overrides the compiled-in default" do
      Application.put_env(:japanese, Translation,
        api_key: "dummy-key",
        models: %{ja_to_en: "claude-haiku-5"}
      )

      assert Translation.model(:ja_to_en) == "claude-haiku-5"
      assert Translation.model(:en_to_ja) == "claude-sonnet-5"
    end

    test ":reading falls back to the shared default like every other operation" do
      Application.put_env(:japanese, Translation, api_key: "dummy-key")

      assert Translation.model(:reading) == "claude-sonnet-5"
    end

    test ":reading can be overridden independently of the other operations" do
      Application.put_env(:japanese, Translation,
        api_key: "dummy-key",
        model: "claude-opus-5",
        models: %{reading: "claude-haiku-5"}
      )

      assert Translation.model(:reading) == "claude-haiku-5"
      assert Translation.model(:explain) == "claude-opus-5"
    end
  end

  describe "ja_to_en/2" do
    test "returns a Translation struct on success" do
      Mimic.expect(Anthropix, :chat, fn _client, _opts -> {:ok, @anthropix_response_en} end)
      result = Translation.ja_to_en("テスト", [])
      assert %Translation{text: "This is a test", usage: usage} = result
      assert usage.input_tokens == 47
      assert usage.output_tokens == 5
    end

    test "returns error on LLM error" do
      Mimic.expect(Anthropix, :chat, fn _client, _opts -> {:error, :llm_error} end)
      assert {:error, :llm_error} = Translation.ja_to_en("テスト", [])
    end
  end

  describe "en_to_ja/2" do
    test "returns a map with :text on success" do
      Mimic.expect(Anthropix, :chat, fn _client, _opts -> {:ok, @anthropix_response} end)
      result = Translation.en_to_ja("This is a test", [])
      assert %{text: "これはテストです"} = result
    end

    test "returns error on LLM error" do
      Mimic.expect(Anthropix, :chat, fn _client, _opts -> {:error, :llm_error} end)
      assert {:error, :llm_error} = Translation.en_to_ja("This is a test", [])
    end
  end

  describe "ja_to_en/2 with mocked Anthropix" do
    test "returns a Translation struct on success" do
      Mimic.expect(Anthropix, :chat, fn _client, _opts ->
        {:ok,
         %{
           "id" => "msg_123",
           "model" => "claude-sonnet-4-20250514",
           "role" => "assistant",
           "type" => "message",
           "content" => [%{"type" => "text", "text" => "This is a test"}],
           "usage" => %{"input_tokens" => 10, "output_tokens" => 5, "service_tier" => "standard"}
         }}
      end)

      result = Translation.ja_to_en("テスト", [])
      assert %Translation{text: "This is a test", usage: usage} = result
      assert usage.input_tokens == 10
      assert usage.output_tokens == 5
    end

    test "returns error on LLM error" do
      Mimic.expect(Anthropix, :chat, fn _client, _opts -> {:error, :llm_error} end)
      assert {:error, :llm_error} = Translation.ja_to_en("テスト", [])
    end
  end

  describe "en_to_ja/2 with mocked Anthropix" do
    test "returns a map with :text on success" do
      Mimic.expect(Anthropix, :chat, fn _client, _opts ->
        {:ok,
         %{
           "id" => "msg_456",
           "model" => "claude-sonnet-4-20250514",
           "role" => "assistant",
           "type" => "message",
           "content" => [%{"type" => "text", "text" => "これはテストです"}],
           "usage" => %{"input_tokens" => 12, "output_tokens" => 6, "service_tier" => "standard"}
         }}
      end)

      result = Translation.en_to_ja("This is a test", [])
      assert %{text: "これはテストです"} = result
    end

    test "returns error on LLM error" do
      Mimic.expect(Anthropix, :chat, fn _client, _opts -> {:error, :llm_error} end)
      assert {:error, :llm_error} = Translation.en_to_ja("This is a test", [])
    end
  end

  describe "reading_for/2" do
    test "returns {:ok, reading} on success and includes the sentence context in the request" do
      sentence = "彼は昨日日本語を勉強した。"

      Mimic.expect(Anthropix, :chat, fn _client, opts ->
        [%{role: "user", content: user_text}] = Keyword.fetch!(opts, :messages)
        assert user_text =~ sentence
        assert user_text =~ "勉強した"

        {:ok,
         %{
           "id" => "msg_reading_1",
           "model" => "claude-sonnet-4-20250514",
           "role" => "assistant",
           "type" => "message",
           "stop_reason" => "end_turn",
           "content" => [%{"type" => "text", "text" => "べんきょうした"}],
           "usage" => %{"input_tokens" => 20, "output_tokens" => 4, "service_tier" => "standard"}
         }}
      end)

      assert Translation.reading_for("勉強した", sentence) == {:ok, "べんきょうした"}
    end

    test "strips the template whitespace that the rendered line arrives wrapped in" do
      # The client reads the context out of a rendered .tr-ja element, so it can
      # arrive carrying the template's indentation and newlines.
      Mimic.expect(Anthropix, :chat, fn _client, opts ->
        [%{role: "user", content: user_text}] = Keyword.fetch!(opts, :messages)

        assert user_text ==
                 "Sentence: 彼は昨日学校に行った。\nSelected portion: 行った"

        {:ok,
         %{
           "id" => "msg_reading_ws",
           "model" => "claude-sonnet-4-20250514",
           "role" => "assistant",
           "type" => "message",
           "stop_reason" => "end_turn",
           "content" => [%{"type" => "text", "text" => "いった"}],
           "usage" => %{
             "input_tokens" => 20,
             "output_tokens" => 3,
             "service_tier" => "standard"
           }
         }}
      end)

      assert Translation.reading_for(
               "  行った ",
               "\n            彼は昨日学校に行った。\n          "
             ) == {:ok, "いった"}
    end

    test "caps max_tokens well above a single word but keeps it bounded, since the selection may be a whole line" do
      Mimic.expect(Anthropix, :chat, fn _client, opts ->
        max_tokens = Keyword.fetch!(opts, :max_tokens)
        # "猫" is a single character, so this hits the floor rather than the
        # per-character scaling — still comfortably above what one word needs.
        assert max_tokens >= 512
        assert max_tokens <= 4096

        {:ok,
         %{
           "id" => "msg_reading_2",
           "model" => "claude-sonnet-4-20250514",
           "role" => "assistant",
           "type" => "message",
           "stop_reason" => "end_turn",
           "content" => [%{"type" => "text", "text" => "ねこ"}],
           "usage" => %{"input_tokens" => 5, "output_tokens" => 2, "service_tier" => "standard"}
         }}
      end)

      assert Translation.reading_for("猫", "猫がいる。") == {:ok, "ねこ"}
    end

    test "scales the token budget up for a long selection instead of pinning one constant" do
      # ~160 characters — a realistic "whole line" selection that would have
      # been squeezed by the old fixed 512 ceiling.
      long_selection = String.duplicate("大変長い文章です", 20)

      Mimic.expect(Anthropix, :chat, fn _client, opts ->
        max_tokens = Keyword.fetch!(opts, :max_tokens)
        assert max_tokens > 512
        assert max_tokens <= 4096

        {:ok,
         %{
           "id" => "msg_reading_long",
           "model" => "claude-sonnet-4-20250514",
           "role" => "assistant",
           "type" => "message",
           "stop_reason" => "end_turn",
           "content" => [%{"type" => "text", "text" => "たいへんながいぶんしょうです"}],
           "usage" => %{
             "input_tokens" => 200,
             "output_tokens" => 40,
             "service_tier" => "standard"
           }
         }}
      end)

      assert {:ok, _reading} = Translation.reading_for(long_selection, long_selection)
    end

    test "caps the token budget so a pathologically long selection can't balloon it unboundedly" do
      huge_selection = String.duplicate("あ", 5000)

      Mimic.expect(Anthropix, :chat, fn _client, opts ->
        assert Keyword.fetch!(opts, :max_tokens) == 4096

        {:ok,
         %{
           "id" => "msg_reading_huge",
           "model" => "claude-sonnet-4-20250514",
           "role" => "assistant",
           "type" => "message",
           "stop_reason" => "end_turn",
           "content" => [%{"type" => "text", "text" => "ああああ"}],
           "usage" => %{
             "input_tokens" => 5000,
             "output_tokens" => 4096,
             "service_tier" => "standard"
           }
         }}
      end)

      assert {:ok, _reading} = Translation.reading_for(huge_selection, huge_selection)
    end

    test "preserves katakana (loanwords) verbatim instead of forcing hiragana" do
      Mimic.expect(Anthropix, :chat, fn _client, _opts ->
        {:ok,
         %{
           "id" => "msg_reading_3",
           "model" => "claude-sonnet-4-20250514",
           "role" => "assistant",
           "type" => "message",
           "stop_reason" => "end_turn",
           "content" => [%{"type" => "text", "text" => "コーヒー"}],
           "usage" => %{"input_tokens" => 5, "output_tokens" => 2, "service_tier" => "standard"}
         }}
      end)

      assert Translation.reading_for("コーヒー", "コーヒーを飲んだ。") == {:ok, "コーヒー"}
    end

    test "returns :unknown (not a guess) when the model can't tell, tolerating padding/punctuation" do
      Mimic.expect(Anthropix, :chat, fn _client, _opts ->
        {:ok,
         %{
           "id" => "msg_reading_4",
           "model" => "claude-sonnet-4-20250514",
           "role" => "assistant",
           "type" => "message",
           "stop_reason" => "end_turn",
           "content" => [%{"type" => "text", "text" => " Unknown. \n"}],
           "usage" => %{"input_tokens" => 5, "output_tokens" => 2, "service_tier" => "standard"}
         }}
      end)

      assert Translation.reading_for("名前", "名前は分からない。") == :unknown
    end

    test "returns {:error, :truncated} instead of a partial reading when the response is cut off" do
      Mimic.expect(Anthropix, :chat, fn _client, _opts ->
        {:ok,
         %{
           "id" => "msg_reading_5",
           "model" => "claude-sonnet-4-20250514",
           "role" => "assistant",
           "type" => "message",
           "stop_reason" => "max_tokens",
           "content" => [%{"type" => "text", "text" => "べんきょ"}],
           "usage" => %{"input_tokens" => 5, "output_tokens" => 512, "service_tier" => "standard"}
         }}
      end)

      assert Translation.reading_for("勉強した", "彼は勉強した。") == {:error, :truncated}
    end

    test "returns error on LLM error" do
      Mimic.expect(Anthropix, :chat, fn _client, _opts -> {:error, :llm_error} end)
      assert {:error, :llm_error} = Translation.reading_for("猫", "猫がいる。")
    end

    test "extracts the reading even when a thinking block precedes the text block" do
      Mimic.expect(Anthropix, :chat, fn _client, _opts ->
        {:ok,
         %{
           "id" => "msg_reading_thinking",
           "model" => "claude-sonnet-4-20250514",
           "role" => "assistant",
           "type" => "message",
           "stop_reason" => "end_turn",
           "content" => [
             %{"type" => "thinking", "thinking" => "considering the reading..."},
             %{"type" => "text", "text" => "べんきょうした"}
           ],
           "usage" => %{"input_tokens" => 20, "output_tokens" => 10, "service_tier" => "standard"}
         }}
      end)

      assert Translation.reading_for("勉強した", "彼は勉強した。") == {:ok, "べんきょうした"}
    end

    test "succeeds even when usage omits service_tier, since Anthropic doesn't guarantee it" do
      Mimic.expect(Anthropix, :chat, fn _client, _opts ->
        {:ok,
         %{
           "id" => "msg_reading_no_tier",
           "model" => "claude-sonnet-4-20250514",
           "role" => "assistant",
           "type" => "message",
           "stop_reason" => "end_turn",
           "content" => [%{"type" => "text", "text" => "ねこ"}],
           "usage" => %{"input_tokens" => 5, "output_tokens" => 2}
         }}
      end)

      assert Translation.reading_for("猫", "猫がいる。") == {:ok, "ねこ"}
    end

    test "returns a clean error atom, never a changeset, when no content block has usable text" do
      Mimic.expect(Anthropix, :chat, fn _client, _opts ->
        {:ok,
         %{
           "id" => "msg_reading_empty",
           "model" => "claude-sonnet-4-20250514",
           "role" => "assistant",
           "type" => "message",
           "stop_reason" => "max_tokens",
           "content" => [%{"type" => "text", "text" => ""}],
           "usage" => %{"input_tokens" => 5, "output_tokens" => 0, "service_tier" => "standard"}
         }}
      end)

      assert {:error, reason} = Translation.reading_for("猫", "猫がいる。")
      refute match?(%Ecto.Changeset{}, reason)
      refute is_struct(reason)
    end
  end

  describe "translate_page/1" do
    test "writes a translation file for a page (translation file: <number>tr.yaml)" do
      story_name = "mystory"
      page = %Japanese.Corpus.Page{number: 5, story: story_name}
      japanese_text = "そして私は預言者と共に王都に向かうことになったのだ。"

      Mimic.expect(Japanese.Corpus.Page, :get_japanese_text, fn ^page -> {:ok, japanese_text} end)

      Mimic.expect(Japanese.Corpus.Story, :get_by_name, fn ^story_name ->
        {:ok, %Japanese.Corpus.Story{}}
      end)

      Mimic.expect(Anthropix, :chat, fn _client, _opts -> {:ok, @anthropix_response_en} end)

      assert :ok = Translation.translate_page(page)
    end
  end

  describe "translate_page/1 pairing" do
    @reply_lines [
      "1\tVisitor ②",
      "2\t◇◆◇",
      "!CONTINUED!\t3",
      "3\tI hear loud voices."
    ]

    test "numbers the lines it sends and aligns the reply to the source when the model drifts" do
      story_name = "mystory"
      page = %Japanese.Corpus.Page{number: 5, story: story_name}

      japanese_text =
        "来訪者　②\n\n◇◆◇\n\n　大きな声が聞こえてくる。\n\n　そんなことを思いながら私は扉を開けた。\n"

      test_pid = self()

      Mimic.expect(Japanese.Corpus.Page, :get_japanese_text, fn ^page -> {:ok, japanese_text} end)

      Mimic.expect(Japanese.Corpus.Story, :get_by_name, fn ^story_name ->
        {:ok, %Japanese.Corpus.Story{}}
      end)

      Mimic.expect(Japanese.Corpus.Page, :update_translation, fn ^page, json ->
        send(test_pid, {:translation_json, json})
        :ok
      end)

      Mimic.expect(Anthropix, :chat, fn _client, opts ->
        assert [%{role: "user", content: content}] = Keyword.fetch!(opts, :messages)

        assert content ==
                 "1\t来訪者　②\n\n2\t◇◆◇\n\n3\t大きな声が聞こえてくる。\n\n4\tそんなことを思いながら私は扉を開けた。\n"

        {:ok,
         %{
           @anthropix_response_en
           | "content" => [%{"text" => Enum.join(@reply_lines, "\n"), "type" => "text"}]
         }}
      end)

      assert :ok = Translation.translate_page(page)
      assert_received {:translation_json, json}

      # The model never translated the last line, so that line — and only that
      # line — is left visibly untranslated. Its stray scene marker changes
      # nothing: the source has no blank run of two, so the page has no break.
      assert Jason.decode!(json)["translation"] == [
               %{"japanese" => "来訪者　②", "english" => "Visitor ②"},
               %{"separator" => "◇◆◇"},
               %{"japanese" => "大きな声が聞こえてくる。", "english" => "I hear loud voices."},
               %{"japanese" => "そんなことを思いながら私は扉を開けた。", "english" => nil}
             ]
    end

    test "does not number the text for a one-off translation" do
      Mimic.expect(Anthropix, :chat, fn _client, opts ->
        assert [%{role: "user", content: "テスト"}] = Keyword.fetch!(opts, :messages)

        {:ok, @anthropix_response_en}
      end)

      assert %Translation{} = Translation.ja_to_en("テスト", [])
    end
  end
end
