defmodule Test.Japanese.OpenRouter do
  use ExUnit.Case, async: false
  use Mimic

  alias Japanese.OpenRouter

  setup :verify_on_exit!

  defp body(message, finish_reason \\ "stop") do
    %{
      "model" => "deepseek/deepseek-v4.1-flash",
      "choices" => [%{"message" => message, "finish_reason" => finish_reason}],
      "usage" => %{"prompt_tokens" => 120, "completion_tokens" => 40}
    }
  end

  describe "parse_completion/2" do
    test "returns the text, model and usage" do
      assert {:ok, completion} =
               OpenRouter.parse_completion(
                 body(%{"role" => "assistant", "content" => "Hello"}),
                 "deepseek/deepseek-v4.1-flash"
               )

      assert completion.text == "Hello"
      assert completion.model == "deepseek/deepseek-v4.1-flash"
      assert completion.finish_reason == "stop"
      assert completion.usage == %{input_tokens: 120, output_tokens: 40}
    end

    test "a content filter, an explicit refusal or an empty reply is :refused" do
      assert {:error, :refused} =
               OpenRouter.parse_completion(body(%{"content" => ""}, "content_filter"), "m")

      assert {:error, :refused} =
               OpenRouter.parse_completion(
                 body(%{"content" => nil, "refusal" => "I can't help with that."}),
                 "m"
               )

      assert {:error, :refused} = OpenRouter.parse_completion(body(%{"content" => "  "}), "m")
      assert {:error, :refused} = OpenRouter.parse_completion(body(%{"content" => nil}), "m")
    end

    test "an error object in a 200 response is an error" do
      assert {:error, {:openrouter_error, "Provider returned error"}} =
               OpenRouter.parse_completion(
                 %{"error" => %{"message" => "Provider returned error", "code" => 502}},
                 "m"
               )
    end
  end

  describe "chat/4" do
    setup do
      original = Application.get_env(:japanese, OpenRouter)
      Application.put_env(:japanese, OpenRouter, api_key: "or-test-key")

      on_exit(fn ->
        if original,
          do: Application.put_env(:japanese, OpenRouter, original),
          else: Application.delete_env(:japanese, OpenRouter)
      end)
    end

    test "sends one system + user message to the chosen model" do
      Mimic.expect(Req, :post, fn url, opts ->
        assert url == "https://openrouter.ai/api/v1/chat/completions"
        assert opts[:auth] == {:bearer, "or-test-key"}
        assert opts[:finch] == [name: Japanese.Finch]
        assert {"connection", "close"} in opts[:headers]
        assert opts[:receive_timeout] == 90_000

        json = opts[:json]
        assert json.model == "deepseek/deepseek-v4.1-flash"
        assert json.max_tokens == 2000

        assert json.messages == [
                 %{role: "system", content: "Translate"},
                 %{role: "user", content: "テスト"}
               ]

        {:ok, %Req.Response{status: 200, body: body(%{"content" => "Test"})}}
      end)

      assert {:ok, %{text: "Test"}} =
               OpenRouter.chat("deepseek/deepseek-v4.1-flash", "Translate", "テスト",
                 max_tokens: 2000,
                 receive_timeout: 90_000
               )
    end

    test "earlier turns go between the system prompt and the question" do
      Mimic.expect(Req, :post, fn _url, opts ->
        assert opts[:json].messages == [
                 %{role: "system", content: "s"},
                 %{role: "user", content: "猫"},
                 %{role: "assistant", content: "cat"},
                 %{role: "user", content: "why?"}
               ]

        {:ok, %Req.Response{status: 200, body: body(%{"content" => "Because."})}}
      end)

      assert {:ok, %{text: "Because."}} =
               OpenRouter.chat("m", "s", "why?",
                 history: [%{role: "user", content: "猫"}, %{role: "assistant", content: "cat"}]
               )
    end

    test "a non-200 response is an error with the provider's message" do
      Mimic.expect(Req, :post, fn _url, _opts ->
        {:ok,
         %Req.Response{status: 402, body: %{"error" => %{"message" => "Insufficient credits"}}}}
      end)

      assert {:error, {:openrouter_http, 402, "Insufficient credits"}} =
               OpenRouter.chat("m", "s", "u")
    end

    test "without an API key nothing is sent" do
      Application.delete_env(:japanese, OpenRouter)
      Mimic.reject(&Req.post/2)

      refute OpenRouter.configured?()
      assert {:error, :missing_openrouter_api_key} = OpenRouter.chat("m", "s", "u")
    end
  end
end
