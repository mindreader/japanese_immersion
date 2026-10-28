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
    # No OpenRouter by default: the chain is just its Anthropic entry, as if
    # OPENROUTER_API_KEY were unset. Tests of the chain turn it on.
    Mimic.stub(Japanese.OpenRouter, :configured?, fn -> false end)
    :ok
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

  describe "model chain" do
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

    # The default chain's OpenRouter entries, as OpenRouter model ids.
    defp openrouter_models(operation) do
      for "openrouter/" <> model <- Translation.chain(operation), do: model
    end

    test "Claude answering normally never touches OpenRouter" do
      Mimic.stub(OpenRouter, :configured?, fn -> true end)
      Mimic.reject(&OpenRouter.chat/4)

      Mimic.expect(Anthropix, :chat, fn _client, opts ->
        assert opts[:model] == "claude-sonnet-5-5"
        {:ok, @anthropix_response_en}
      end)

      assert %Translation{text: "This is a test", model: "anthropic/claude-sonnet-5-5"} =
               Translation.ja_to_en("テスト", [])
    end

    test "an empty refusal is :refused, not :invalid_response" do
      Mimic.expect(Anthropix, :chat, fn _client, _opts -> {:ok, @refusal} end)

      assert {:error, :refused} = Translation.ja_to_en("テスト", [])
    end

    test "a refusal partway through is a failure, not a short translation" do
      partial = Map.put(@refusal, "content", [%{"type" => "text", "text" => "The first half"}])
      Mimic.expect(Anthropix, :chat, fn _client, _opts -> {:ok, partial} end)

      assert {:error, :refused} = Translation.ja_to_en("テスト", [])
    end

    test "a refusal moves on to the next entry, with the same prompt" do
      Mimic.stub(OpenRouter, :configured?, fn -> true end)
      [first | _] = openrouter_models(:ja_to_en)

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

      assert %Translation{text: "This is a test", model: model, usage: usage} =
               Translation.ja_to_en("テスト", [])

      assert model == "openrouter/" <> first
      assert usage.output_tokens == 900
    end

    test "an Anthropic error (not just a refusal) moves on too" do
      Mimic.stub(OpenRouter, :configured?, fn -> true end)
      [first | _] = openrouter_models(:ja_to_en)
      Mimic.expect(Anthropix, :chat, fn _client, _opts -> {:error, :llm_error} end)
      Mimic.expect(OpenRouter, :chat, fn ^first, _s, _u, _o -> completion("Rescued", first) end)

      assert %Translation{text: "Rescued"} = Translation.ja_to_en("テスト", [])
    end

    test "goes down the chain in order until one answers" do
      Mimic.stub(OpenRouter, :configured?, fn -> true end)
      [first, second, third | _] = openrouter_models(:ja_to_en)
      Mimic.expect(Anthropix, :chat, fn _client, _opts -> {:ok, @refusal} end)

      Mimic.expect(OpenRouter, :chat, 3, fn
        ^first, _s, _u, _o -> {:error, :refused}
        ^second, _s, _u, _o -> {:error, {:openrouter_http, 503, "busy"}}
        ^third, _s, _u, _o -> completion("Third time lucky", third)
      end)

      assert %Translation{text: "Third time lucky", model: model} =
               Translation.ja_to_en("テスト", [])

      assert model == "openrouter/" <> third
    end

    test "every entry failing lists each failure" do
      Mimic.stub(OpenRouter, :configured?, fn -> true end)
      Mimic.expect(Anthropix, :chat, fn _client, _opts -> {:ok, @refusal} end)

      Mimic.expect(OpenRouter, :chat, length(openrouter_models(:ja_to_en)), fn
        _model, _system, _user, _opts -> {:error, :refused}
      end)

      assert {:error, {:all_models_failed, failures}} = Translation.ja_to_en("テスト", [])
      assert Enum.map(failures, &elem(&1, 0)) == Translation.chain(:ja_to_en)
      assert Enum.all?(failures, &match?({_entry, :refused}, &1))
    end

    test "explanations use the chain too" do
      Mimic.stub(OpenRouter, :configured?, fn -> true end)
      [first | _] = openrouter_models(:explain)
      Mimic.expect(Anthropix, :chat, fn _client, _opts -> {:ok, @refusal} end)

      Mimic.expect(OpenRouter, :chat, fn ^first, _s, _u, _o ->
        completion("A breakdown", first)
      end)

      assert "A breakdown" = Translation.explain_text("テスト")
    end

    test "screenshots send their image to OpenRouter in its format" do
      Mimic.stub(OpenRouter, :configured?, fn -> true end)
      [first | _] = openrouter_models(:screenshot)
      Mimic.expect(Anthropix, :chat, fn _client, _opts -> {:ok, @refusal} end)

      Mimic.expect(OpenRouter, :chat, fn ^first, _system, user, opts ->
        assert [
                 %{type: "image_url", image_url: %{url: "data:image/png;base64," <> data}},
                 %{type: "text", text: "OCR lines" <> _}
               ] = user

        assert Base.decode64!(data) == "png bytes"
        assert opts[:max_tokens] == 8192
        completion(~s|{"description": "menu"}|, first)
      end)

      assert {:ok, ~s|{"description": "menu"}|, model} =
               Translation.transcribe_screenshot("png bytes", "image/png", "[x] テスト")

      assert model == "openrouter/" <> first
    end
  end
end
