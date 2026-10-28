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
      [first, second | _] = openrouter_models(:ja_to_en)
      Mimic.expect(Anthropix, :chat, fn _client, _opts -> {:ok, @refusal} end)

      Mimic.expect(OpenRouter, :chat, 2, fn
        ^first, _s, _u, _o -> {:error, {:openrouter_http, 503, "busy"}}
        ^second, _s, _u, _o -> completion("Second time lucky", second)
      end)

      assert %Translation{text: "Second time lucky", model: model} =
               Translation.ja_to_en("テスト", [])

      assert model == "openrouter/" <> second
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

  describe "pages every model refuses" do
    # Six paragraphs of ten lines (a break is two blank lines in this format);
    # line 25 is the one the "filter" objects to.
    @page Enum.map_join(0..5, "\n\n\n", fn p ->
            Enum.map_join(1..10, "\n", fn i ->
              n = p * 10 + i
              if n == 25, do: "問題の行です。", else: "これは#{n}行目です。"
            end)
          end)

    defp reply(text) do
      %{
        "content" => [%{"type" => "text", "text" => text}],
        "id" => "msg",
        "model" => "claude-sonnet-5-5",
        "role" => "assistant",
        "stop_reason" => "end_turn",
        "type" => "message",
        "usage" => %{"input_tokens" => 10, "output_tokens" => 10}
      }
    end

    @refused %{
      "content" => [],
      "id" => "msg",
      "model" => "claude-sonnet-5-5",
      "role" => "assistant",
      "stop_reason" => "refusal",
      "type" => "message",
      "usage" => %{"input_tokens" => 10, "output_tokens" => 0}
    }

    # Translates every numbered line of the request as "Line <n>".
    defp translate_request(opts) do
      [%{content: numbered}] = opts[:messages]

      numbered
      |> String.split("\n")
      |> Enum.flat_map(fn line ->
        case Regex.run(~r/^(\d+)\t/, line) do
          [_, n] -> ["#{n}\tLine #{n}"]
          nil -> []
        end
      end)
      |> Enum.join("\n")
    end

    defp request_lines(opts) do
      [%{content: numbered}] = opts[:messages]
      for line <- String.split(numbered, "\n"), line != "", do: line
    end

    # The whole page is refused, as is any piece holding line 25. Pieces run
    # in their own tasks, so requests are reported to the test process.
    defp filter_line_25(test) do
      fn _client, opts ->
        lines = request_lines(opts)
        send(test, {:request, length(lines)})

        cond do
          length(lines) == 60 -> {:ok, @refused}
          Enum.any?(lines, &String.contains?(&1, "問題")) -> {:ok, @refused}
          true -> {:ok, reply(translate_request(opts))}
        end
      end
    end

    test "a page that's translated whole is not split" do
      Mimic.expect(Anthropix, :chat, fn _client, opts -> {:ok, reply(translate_request(opts))} end)

      assert {:ok, text} = Translation.translate_page_text(@page)
      assert length(String.split(text, "\n")) == 60
    end

    test "a refused page is translated in pieces, leaving only the refused piece out" do
      Mimic.stub(Anthropix, :chat, filter_line_25(self()))

      assert {:ok, text} = Translation.translate_page_text(@page, "story page 184")

      numbers =
        for line <- String.split(text, "\n"),
            do: line |> String.split("\t") |> hd() |> String.to_integer()

      # Pieces fall on paragraph breaks: 1-20, 21-40 (refused), 41-60.
      assert numbers == Enum.to_list(1..20) ++ Enum.to_list(41..60)
      assert "41\tLine 41" in String.split(text, "\n")

      # One whole-page request, then three pieces of 20 lines.
      assert_received {:request, 60}
      for _ <- 1..3, do: assert_received({:request, 20})
    end

    test "the merged reply pairs with the page, refused lines saved as not translated" do
      Mimic.stub(Anthropix, :chat, filter_line_25(self()))

      {:ok, text} = Translation.translate_page_text(@page)

      {:ok, %{translation: entries}} =
        text
        |> Translation.Json.format_to_translation_json(@page)
        |> Translation.Json.decode_translation()

      lines = Enum.filter(entries, &Map.has_key?(&1, :japanese))
      assert length(lines) == 60
      assert Enum.at(lines, 0) == %{japanese: "これは1行目です。", english: "Line 1"}
      assert Enum.at(lines, 24) == %{japanese: "問題の行です。", english: nil}
      assert Enum.at(lines, 20).english == nil
      assert Enum.at(lines, 40) == %{japanese: "これは41行目です。", english: "Line 41"}
      assert Enum.count(entries, &Map.has_key?(&1, :paragraph_break)) == 5
    end

    test "if every piece is refused, the page fails with the original error" do
      Mimic.stub(Anthropix, :chat, fn _client, _opts -> {:ok, @refused} end)

      assert {:error, :refused} = Translation.translate_page_text(@page)
    end

    test "a failure that isn't a refusal is not retried in pieces" do
      Mimic.expect(Anthropix, :chat, fn _client, _opts -> {:error, :llm_error} end)

      assert {:error, :llm_error} = Translation.translate_page_text(@page)
    end

    test "a prose refusal counts as a refusal, not as a translation" do
      Mimic.stub(Anthropix, :chat, fn _client, opts ->
        if length(request_lines(opts)) == 60,
          do: {:ok, reply("I'm sorry, but I can't help translate this passage.")},
          else: {:ok, reply(translate_request(opts))}
      end)

      assert {:ok, text} = Translation.translate_page_text(@page)
      assert length(String.split(text, "\n")) == 60
      refute text =~ "sorry"
    end

    test "a whole-page translation that ignored the numbering is still accepted" do
      Mimic.expect(Anthropix, :chat, fn _client, opts ->
        bare = opts |> translate_request() |> String.replace(~r/^\d+\t/m, "")
        {:ok, reply(bare)}
      end)

      assert {:ok, text} = Translation.translate_page_text(@page)
      refute text =~ ~r/^\d+\t/m
    end

    test "refused?/1" do
      assert Translation.refused?(:refused)
      assert Translation.refused?({:all_models_failed, [{"a/b", :refused}, {"c/d", :refused}]})
      refute Translation.refused?({:all_models_failed, [{"a/b", :refused}, {"c/d", :timeout}]})
      refute Translation.refused?({:all_models_failed, []})
      refute Translation.refused?(:timeout)
    end
  end

  describe "screening a refused page" do
    # 60 lines, ten per paragraph; lines 25-26 are a passage the screen
    # withholds (a minor's age next to a weak term). The mock "filter"
    # refuses any request containing line 26.
    @screened_page Enum.map_join(0..5, "\n\n\n", fn p ->
                     Enum.map_join(1..10, "\n", fn i ->
                       case p * 10 + i do
                         25 -> "彼は十三歳だ。"
                         26 -> "もう経験したのか。"
                         n -> "これは#{n}行目です。"
                       end
                     end)
                   end)

    defp refuse_line_26(test) do
      fn _client, opts ->
        lines = request_lines(opts)
        send(test, {:request, lines})

        if Enum.any?(lines, &String.contains?(&1, "経験")),
          do: {:ok, @refused},
          else: {:ok, reply(translate_request(opts))}
      end
    end

    test "withheld lines are never sent; the rest goes as one request" do
      Mimic.stub(Anthropix, :chat, refuse_line_26(self()))

      assert {:ok, text} = Translation.translate_page_text(@screened_page, "story page 1")

      numbers =
        for line <- String.split(text, "\n"),
            do: line |> String.split("\t") |> hd() |> String.to_integer()

      # The screen pads the passage by a line either side.
      assert numbers == Enum.to_list(1..23) ++ Enum.to_list(28..60)

      # The whole page, then the screened page in one request; no pieces.
      assert_received {:request, whole}
      assert length(whole) == 60
      assert_received {:request, screened}
      assert length(screened) == 56
      refute Enum.any?(screened, &String.contains?(&1, "十三歳"))
      refute_received {:request, _}
    end

    test "if the screened page is refused too, only screened pieces are sent" do
      # Refuse anything with line 30 in it as well, which the screen misses.
      # Pieces run in their own tasks, so requests go to the test process.
      test = self()

      Mimic.stub(Anthropix, :chat, fn _client, opts ->
        lines = request_lines(opts)
        send(test, {:request, lines})

        if Enum.any?(lines, &String.contains?(&1, ["経験", "これは30行目"])),
          do: {:ok, @refused},
          else: {:ok, reply(translate_request(opts))}
      end)

      assert {:ok, text} = Translation.translate_page_text(@screened_page)

      numbers =
        for line <- String.split(text, "\n"),
            do: line |> String.split("\t") |> hd() |> String.to_integer()

      # The piece holding line 30 is lost; the withheld lines are too.
      refute 30 in numbers
      assert 1 in numbers and 60 in numbers
      refute Enum.any?(24..27, &(&1 in numbers))

      # After the whole page, nothing sent again contains a withheld line.
      assert_received {:request, whole}
      assert length(whole) == 60

      for {:request, lines} <- collect_requests() do
        refute Enum.any?(lines, &String.contains?(&1, ["十三歳", "経験"]))
      end
    end

    test "the merged reply saves withheld lines as not translated" do
      Mimic.stub(Anthropix, :chat, refuse_line_26(self()))

      {:ok, text} = Translation.translate_page_text(@screened_page)

      {:ok, %{translation: entries}} =
        text
        |> Translation.Json.format_to_translation_json(@screened_page)
        |> Translation.Json.decode_translation()

      lines = Enum.filter(entries, &Map.has_key?(&1, :japanese))
      assert length(lines) == 60
      assert Enum.at(lines, 24) == %{japanese: "彼は十三歳だ。", english: nil}
      assert Enum.at(lines, 25) == %{japanese: "もう経験したのか。", english: nil}
      assert Enum.at(lines, 22).english == "Line 23"
      assert Enum.at(lines, 27).english == "Line 28"
    end

    defp collect_requests(acc \\ []) do
      receive do
        {:request, _} = msg -> collect_requests([msg | acc])
      after
        0 -> Enum.reverse(acc)
      end
    end
  end
end
