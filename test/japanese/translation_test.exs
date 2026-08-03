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

    test "caps max_tokens low but well above a single word, since the selection may be a whole line" do
      Mimic.expect(Anthropix, :chat, fn _client, opts ->
        assert Keyword.fetch!(opts, :max_tokens) == 512

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
end
