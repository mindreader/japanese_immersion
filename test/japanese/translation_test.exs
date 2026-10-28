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

      assert Translation.model(:ja_to_en) == "claude-sonnet-5-5"
      assert Translation.model(:en_to_ja) == "claude-sonnet-5-5"
      assert Translation.model(:explain) == "claude-sonnet-5-5"
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
      assert Translation.model(:en_to_ja) == "claude-sonnet-5-5"
    end
  end

  describe "Anthropic client" do
    test "asks for Connection: close so no connection is kept idle in the pool" do
      Mimic.expect(Anthropix, :chat, fn %Anthropix{req: req}, _opts ->
        assert Req.Request.get_header(req, "connection") == ["close"]
        assert req.options.finch == [name: Japanese.Finch]
        {:ok, @anthropix_response_en}
      end)

      assert %Translation{} = Translation.ja_to_en("テスト", [])
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

  describe "refusals" do
    alias Japanese.OpenRouter

    @refusal %{
      "content" => [],
      "id" => "msg_refused",
      "model" => "claude-sonnet-5-5",
      "role" => "assistant",
      "stop_reason" => "refusal",
      "stop_sequence" => nil,
      "type" => "message",
      "usage" => %{"input_tokens" => 3000, "output_tokens" => 0}
    }

    defp completion(text, model) do
      {:ok,
       %{
         text: text,
         model: model,
         finish_reason: "stop",
         usage: %{input_tokens: 3100, output_tokens: 900}
       }}
    end

    test "an empty refusal is :refused, not :invalid_response" do
      Mimic.stub(OpenRouter, :configured?, fn -> false end)
      Mimic.expect(Anthropix, :chat, fn _client, _opts -> {:ok, @refusal} end)

      assert {:error, :refused} = Translation.ja_to_en("テスト", [])
    end

    test "a refusal partway through is a failure, not a short translation" do
      Mimic.stub(OpenRouter, :configured?, fn -> false end)

      partial = Map.put(@refusal, "content", [%{"type" => "text", "text" => "The first half"}])
      Mimic.expect(Anthropix, :chat, fn _client, _opts -> {:ok, partial} end)

      assert {:error, :refused} = Translation.ja_to_en("テスト", [])
    end

    test "falls back to the first OpenRouter model, with the same prompt" do
      Mimic.stub(OpenRouter, :configured?, fn -> true end)
      [first | _] = Translation.fallback_models()

      Mimic.expect(Anthropix, :chat, fn _client, opts ->
        send(self(), {:claude, opts[:system], opts[:messages]})
        {:ok, @refusal}
      end)

      Mimic.expect(OpenRouter, :chat, fn ^first, system, user, opts ->
        assert_received {:claude, ^system, [%{role: "user", content: ^user}]}
        assert opts[:max_tokens] == 16_384
        assert opts[:receive_timeout] <= 180_000
        completion("This is a test", first)
      end)

      assert %Translation{text: "This is a test", model: ^first, usage: usage} =
               Translation.ja_to_en("テスト", [])

      assert usage.output_tokens == 900
    end

    test "tries the next model when one refuses or errors" do
      Mimic.stub(OpenRouter, :configured?, fn -> true end)
      [first, second | _] = Translation.fallback_models()
      Mimic.expect(Anthropix, :chat, fn _client, _opts -> {:ok, @refusal} end)

      Mimic.expect(OpenRouter, :chat, 2, fn
        ^first, _system, _user, _opts -> {:error, :refused}
        ^second, _system, _user, _opts -> completion("Second time lucky", second)
      end)

      assert %Translation{text: "Second time lucky", model: ^second} =
               Translation.ja_to_en("テスト", [])
    end

    test ":fallbacks_failed when every fallback fails" do
      Mimic.stub(OpenRouter, :configured?, fn -> true end)
      Mimic.expect(Anthropix, :chat, fn _client, _opts -> {:ok, @refusal} end)

      Mimic.expect(OpenRouter, :chat, length(Translation.fallback_models()), fn
        _model, _system, _user, _opts -> {:error, {:openrouter_http, 503, "busy"}}
      end)

      assert {:error, :fallbacks_failed} = Translation.ja_to_en("テスト", [])
    end

    test "explanations fall back too" do
      Mimic.stub(OpenRouter, :configured?, fn -> true end)
      [first | _] = Translation.fallback_models()
      Mimic.expect(Anthropix, :chat, fn _client, _opts -> {:ok, @refusal} end)

      Mimic.expect(OpenRouter, :chat, fn ^first, _s, _u, _o ->
        completion("A breakdown", first)
      end)

      assert "A breakdown" = Translation.explain_text("テスト")
    end

    test "screenshots don't fall back (their request carries an image)" do
      Mimic.stub(OpenRouter, :configured?, fn -> true end)
      Mimic.reject(&OpenRouter.chat/4)
      Mimic.expect(Anthropix, :chat, fn _client, _opts -> {:ok, @refusal} end)

      assert {:error, :refused} = Translation.transcribe_screenshot("png", "image/png", "[x] テスト")
    end

    test "Claude answering normally never touches OpenRouter" do
      Mimic.stub(OpenRouter, :configured?, fn -> true end)
      Mimic.reject(&OpenRouter.chat/4)
      Mimic.expect(Anthropix, :chat, fn _client, _opts -> {:ok, @anthropix_response_en} end)

      assert %Translation{text: "This is a test", model: "claude-sonnet-4-20250514"} =
               Translation.ja_to_en("テスト", [])
    end
  end
end
