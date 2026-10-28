defmodule Japanese.OpenRouter do
  @moduledoc """
  Minimal OpenRouter chat-completions client, used as a fallback when Claude
  declines a request (see `Japanese.Translation`).

  OpenRouter speaks the OpenAI chat-completions format for every model it
  routes to, so one client covers DeepSeek, Gemini, Qwen and the rest.

  Configured with `config :japanese, Japanese.OpenRouter, api_key: "..."`
  (from `OPENROUTER_API_KEY` in `config/runtime.exs`). With no key there is
  no fallback, and `configured?/0` is false.
  """

  @endpoint "https://openrouter.ai/api/v1/chat/completions"

  @type completion :: %{
          text: String.t(),
          model: String.t(),
          finish_reason: String.t() | nil,
          usage: %{input_tokens: non_neg_integer(), output_tokens: non_neg_integer()}
        }

  @doc "Whether an API key is configured."
  @spec configured?() :: boolean()
  def configured?, do: match?({:ok, _}, api_key())

  @doc """
  Sends one system prompt + user message to `model`.

  Returns `{:ok, completion}` with the reply text, or an error:

    * `{:error, :refused}` - the model or the provider's moderation declined
      (finish reason `content_filter`, an OpenAI-style `refusal`, or an empty
      reply)
    * `{:error, {:openrouter_http, status, message}}` - a non-200 response
    * `{:error, :missing_openrouter_api_key}`
    * `{:error, exception}` - a transport error from Req

  ## Options
    * `:max_tokens` (default 16_384)
    * `:receive_timeout` in ms (default 180_000)
  """
  @spec chat(String.t(), String.t(), String.t(), Keyword.t()) ::
          {:ok, completion()} | {:error, term()}
  def chat(model, system_prompt, user_text, opts \\ [])
      when is_binary(model) and is_binary(system_prompt) and is_binary(user_text) do
    with {:ok, key} <- api_key() do
      body = %{
        model: model,
        messages: [
          %{role: "system", content: system_prompt},
          %{role: "user", content: user_text}
        ],
        max_tokens: Keyword.get(opts, :max_tokens, 16_384),
        # Reasoning models: keep any thinking out of the reply text.
        reasoning: %{exclude: true}
      }

      case Req.post(@endpoint,
             json: body,
             auth: {:bearer, key},
             finch: [name: Japanese.Finch],
             # One connection per call, never pooled: see Japanese.HTTP.
             headers:
               Japanese.HTTP.no_keepalive_headers() ++
                 [{"x-title", "Japanese Immersion"}],
             receive_timeout: Keyword.get(opts, :receive_timeout, 180_000),
             retry: :transient,
             max_retries: 2
           ) do
        {:ok, %Req.Response{status: 200, body: body}} when is_map(body) ->
          parse_completion(body, model)

        {:ok, %Req.Response{status: status, body: body}} ->
          {:error, {:openrouter_http, status, error_message(body)}}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  @doc """
  Turns a chat-completions response body into a completion, or
  `{:error, :refused}` / `{:error, {:openrouter_error, message}}`.

  OpenRouter can answer 200 with an `error` object when the upstream provider
  failed mid-stream, so that is checked as well as the status code.
  """
  @spec parse_completion(map(), String.t()) :: {:ok, completion()} | {:error, term()}
  def parse_completion(%{"error" => error}, _requested_model) do
    {:error, {:openrouter_error, error_message(%{"error" => error})}}
  end

  def parse_completion(%{"choices" => [choice | _]} = body, requested_model) do
    message = Map.get(choice, "message") || %{}
    text = Map.get(message, "content")
    finish_reason = Map.get(choice, "finish_reason")
    refusal = Map.get(message, "refusal")

    cond do
      finish_reason == "content_filter" ->
        {:error, :refused}

      is_binary(refusal) and refusal != "" ->
        {:error, :refused}

      not is_binary(text) or String.trim(text) == "" ->
        {:error, :refused}

      true ->
        usage = Map.get(body, "usage") || %{}

        {:ok,
         %{
           text: text,
           model: Map.get(body, "model") || requested_model,
           finish_reason: finish_reason,
           usage: %{
             input_tokens: Map.get(usage, "prompt_tokens") || 0,
             output_tokens: Map.get(usage, "completion_tokens") || 0
           }
         }}
    end
  end

  def parse_completion(_body, _requested_model), do: {:error, {:openrouter_error, "no choices"}}

  defp error_message(%{"error" => %{"message" => message}}) when is_binary(message), do: message
  defp error_message(%{"error" => error}) when is_binary(error), do: error
  defp error_message(body) when is_binary(body), do: String.slice(body, 0, 200)
  defp error_message(_), do: "unknown error"

  defp api_key do
    case Application.get_env(:japanese, __MODULE__, [])[:api_key] do
      key when is_binary(key) and key != "" -> {:ok, key}
      _ -> {:error, :missing_openrouter_api_key}
    end
  end
end
