defmodule Japanese.Fal do
  defmodule QueuedRequest do
    @moduledoc """
    Represents a queued request from the Fal API.
    """

    defstruct [
      :request_id,
      :model,
      :status,
      :queue_position,
      :status_path,
      :response_path,
      :cancel_path
    ]

    @doc """
    Parses the queue response body and extracts URL fragments.
    """
    def from_response(body) do
      request_id = body["request_id"]
      status_path = extract_path(body["status_url"])
      response_path = extract_path(body["response_url"])
      cancel_path = extract_path(body["cancel_url"])

      # Extract model from any of the URLs
      model = extract_model(body["status_url"])

      %__MODULE__{
        request_id: request_id,
        model: model,
        status: body["status"],
        queue_position: body["queue_position"],
        status_path: status_path,
        response_path: response_path,
        cancel_path: cancel_path
      }
    end

    defp extract_path(url) when is_binary(url) do
      URI.parse(url).path |> String.trim_leading("/")
    end

    defp extract_path(_), do: nil

    defp extract_model(url) when is_binary(url) do
      case String.split(URI.parse(url).path, "/requests/") do
        [model_path | _] -> String.trim_leading(model_path, "/")
        _ -> nil
      end
    end

    defp extract_model(_), do: nil
  end

  @doc """
  Queue a job using the Fal API.

  ## Parameters
  - `model` - The model to use (e.g., "fal-ai/qwen-image-edit-plus-lora")
  - `data` - Map of data to send to the API
  - `opts` - Optional keyword list with the following supported options:
    - `:connect_timeout` - Connection timeout in milliseconds (integer, defaults to 20000)
    - `:receive_timeout` - Receive timeout in milliseconds (integer, defaults to 20000)

  ## Examples
      iex> Japanese.Fal.Fal.queue(
      ...>   "fal-ai/qwen-image-edit-plus-lora",
      ...>   %{
      ...>     prompt: "Close shot of a woman standing in next to this car on this highway",
      ...>     image_urls: [
      ...>       "https://v3.fal.media/files/monkey/i3saq4bAPXSIl08nZtq9P_ec535747aefc4e31943136a6d8587075.png"
      ...>     ]
      ...>   }
      ...> )
      {:ok, %QueuedRequest{}}
  """
  def queue(model, data, opts \\ []) when (is_binary(model) or is_atom(model)) and is_map(data) do
    timeout_opts = build_timeout_opts(opts)

    model = to_string(model)

    post(model, data, timeout_opts)
    |> case do
      {:ok, %Tesla.Env{status: 200, body: body}} ->
        {:ok, QueuedRequest.from_response(body)}

      error ->
        error
    end
  end

  @doc """
  Queue a job and wait for completion.

  Queues a job, then periodically polls the status until it's no longer "IN_QUEUE",
  then retrieves and returns the response.

  ## Parameters
  - `model` - The model to use (e.g., "fal-ai/qwen-image-edit-plus-lora" or :"fal-ai/kokoro/japanese")
  - `data` - Map of data to send to the API
  - `opts` - Optional keyword list with the following supported options:
    - `:poll_interval` - Milliseconds between status checks (integer, defaults to 1000)
    - `:max_wait_time` - Maximum time to wait in milliseconds (integer, defaults to 300000 - 5 minutes)
    - `:connect_timeout` - Connection timeout in milliseconds (integer, defaults to 20000)
    - `:receive_timeout` - Receive timeout in milliseconds (integer, defaults to 20000)

  ## Examples
      iex> Japanese.Fal.Fal.queue_and_wait(
      ...>   "fal-ai/qwen-image-edit-plus-lora",
      ...>   %{prompt: "...", image_urls: [...]}
      ...> )
      {:ok, %{...}}
  """
  def queue_and_wait(model, data, opts \\ [])
      when (is_binary(model) or is_atom(model)) and is_map(data) do
    poll_interval = Keyword.get(opts, :poll_interval, 1000)
    max_wait_time = Keyword.get(opts, :max_wait_time, 300_000)
    start_time = System.monotonic_time(:millisecond)

    with {:ok, queued_request} <- queue(model, data, opts) do
      poll_until_complete(queued_request, poll_interval, max_wait_time, start_time, opts)
    end
  end

  defp poll_until_complete(queued_request, poll_interval, max_wait_time, start_time, opts) do
    elapsed = System.monotonic_time(:millisecond) - start_time

    if elapsed >= max_wait_time do
      {:error, :timeout}
    else
      case status(queued_request, opts) do
        {:ok, %{"status" => status}} when status in ["IN_QUEUE", "IN_PROGRESS"] ->
          Process.sleep(poll_interval)
          poll_until_complete(queued_request, poll_interval, max_wait_time, start_time, opts)

        {:ok, %{"status" => "COMPLETED"}} ->
          response(queued_request, opts)

        {:ok, %{"status" => other_status}} ->
          {:error, {:unexpected_status, other_status}}

        error ->
          error
      end
    end
  end

  @doc """
  Check the status of a queued job.

  ## Parameters
  - `queued_request` - A QueuedRequest struct
  - `opts` - Optional keyword list with the following supported options:
    - `:connect_timeout` - Connection timeout in milliseconds (integer, defaults to 20000)
    - `:receive_timeout` - Receive timeout in milliseconds (integer, defaults to 20000)

  ## Examples
      iex> Japanese.Fal.Fal.status(queued_request)
      {:ok, %{...}}
  """
  def status(%QueuedRequest{status_path: path} = _queued_request, opts \\ []) do
    timeout_opts = build_timeout_opts(opts)

    get(path, timeout_opts)
    |> case do
      {:ok, %Tesla.Env{status: status, body: body}} when status in [200, 202] ->
        {:ok, body}

      error ->
        error
    end
  end

  @doc """
  Get the response for a completed job.

  ## Parameters
  - `queued_request` - A QueuedRequest struct
  - `opts` - Optional keyword list with the following supported options:
    - `:connect_timeout` - Connection timeout in milliseconds (integer, defaults to 20000)
    - `:receive_timeout` - Receive timeout in milliseconds (integer, defaults to 20000)

  ## Examples
      iex> Japanese.Fal.Fal.response(queued_request)
      {:ok, %{...}}
  """
  def response(%QueuedRequest{response_path: path} = _queued_request, opts \\ []) do
    timeout_opts = build_timeout_opts(opts)

    get(path, timeout_opts)
    |> case do
      {:ok, %Tesla.Env{status: 200, body: body}} ->
        {:ok, body}

      error ->
        error
    end
  end

  @doc """
  Cancel a queued job.

  ## Parameters
  - `queued_request` - A QueuedRequest struct
  - `opts` - Optional keyword list with the following supported options:
    - `:connect_timeout` - Connection timeout in milliseconds (integer, defaults to 20000)
    - `:receive_timeout` - Receive timeout in milliseconds (integer, defaults to 20000)

  ## Examples
      iex> Japanese.Fal.Fal.cancel(queued_request)
      {:ok, %Tesla.Env{}}
  """
  def cancel(%QueuedRequest{cancel_path: path} = _queued_request, opts \\ []) do
    timeout_opts = build_timeout_opts(opts)
    put(path, %{}, timeout_opts)
  end

  @valid_voices [:jf_alpha, :jf_gongitsune, :jf_nezumi, :jf_tebukuro, :jm_kumo]

  @doc """
  Generate Japanese text-to-speech audio and save it to the story's audio directory.

  ## Parameters
  - `voice` - Voice ID atom (one of: :jf_alpha, :jf_gongitsune, :jf_nezumi, :jf_tebukuro, :jm_kumo)
  - `text` - Japanese text to convert to speech
  - `story` - Story name (directory name)
  - `filename` - Filename to save the audio as (e.g., "jf_alpha_abc123.mp3")
  - `opts` - Optional keyword list with the following supported options:
    - `:speed` - Speed of the generated audio (float, defaults to 1.0)
    - `:poll_interval` - Milliseconds between status checks (integer, defaults to 1000)
    - `:max_wait_time` - Maximum time to wait in milliseconds (integer, defaults to 300000)
    - `:connect_timeout` - Connection timeout in milliseconds (integer, defaults to 20000)
    - `:receive_timeout` - Receive timeout in milliseconds (integer, defaults to 20000)

  ## Examples
      iex> Japanese.Fal.tts(:jf_alpha, "こんにちは", "story1", "jf_alpha_abc123.mp3")
      {:ok, "/path/to/corpus/story1/audio/jf_alpha_abc123.mp3"}
  """
  @spec tts(atom(), String.t(), String.t(), String.t(), keyword()) ::
          {:ok, String.t()} | {:error, term()}
  def tts(voice, text, story, filename, opts \\ [])
      when voice in @valid_voices and is_binary(text) and is_binary(story) and
             is_binary(filename) do
    speed = Keyword.get(opts, :speed, 1.0)

    data = %{
      prompt: text,
      voice: voice,
      speed: speed
    }

    with {:ok, response} <- queue_and_wait(:"fal-ai/kokoro/japanese", data, opts),
         {:ok, audio_url} <- extract_audio_url(response),
         storage <- Japanese.Corpus.StorageLayer.new(),
         {:ok, file_path} <-
           Japanese.Corpus.StorageLayer.save_audio_from_url(storage, story, filename, audio_url) do
      {:ok, file_path}
    end
  end

  defp extract_audio_url(%{"audio" => %{"url" => url}}), do: {:ok, url}
  defp extract_audio_url(%{"audio" => url}) when is_binary(url), do: {:ok, url}

  defp extract_audio_url(_) do
    {:error, :audio_url_not_found}
  end

  defp build_timeout_opts(opts) do
    connect_timeout = Keyword.get(opts, :connect_timeout, 20000)
    receive_timeout = Keyword.get(opts, :receive_timeout, 20000)

    [connect_timeout: connect_timeout, receive_timeout: receive_timeout]
  end

  def post(model, body, opts \\ []) do
    Tesla.request(client(opts), method: :post, url: model, body: body)
  end

  def get(url, opts \\ []) do
    Tesla.request(client(opts), method: :get, url: url)
  end

  def put(url, body, opts \\ []) do
    Tesla.request(client(opts), method: :put, url: url, body: body)
  end

  defp client(opts) do
    middleware = [
      {Tesla.Middleware.BaseUrl, "https://queue.fal.run"},
      {Tesla.Middleware.Headers, [{"Authorization", "Key #{api_key()}"}]},
      {Tesla.Middleware.JSON, engine: JSON},
      {Tesla.Middleware.Retry, delay: 1000, max_retries: 3}
    ]

    finch_opts = [
      name: Japanese.Finch,
      connect_timeout: Keyword.get(opts, :connect_timeout, 20000),
      receive_timeout: Keyword.get(opts, :receive_timeout, 20000)
    ]

    Tesla.client(middleware, {Tesla.Adapter.Finch, finch_opts})
  end

  def api_key do
    res = Keyword.fetch!(config(), :api_key)

    if !res do
      raise "FAL_API_KEY is not set!"
    end

    res
  end

  def config do
    Application.get_env(:japanese, __MODULE__, [])
  end
end
