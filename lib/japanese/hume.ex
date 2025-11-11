defmodule Japanese.Hume do
  require Logger
  alias Japanese.Hume.Schemas.TtsResponse
  alias Japanese.Hume.Schemas.VoiceListResponse

  @moduledoc """
  Hume.ai Text-to-Speech provider for generating audio from text with emotional descriptions.
  Also provides voice management capabilities.
  """

  @doc """
  List available voices from Hume API.

  ## Parameters
    * `provider` - Required voice provider: `:hume_ai` or `:custom_voice`
    * `opts` - Optional parameters:
      * `:page_number` - Page number (default: 0)
      * `:page_size` - Page size (default: 10)

  ## Returns
    * `{:ok, voice_list_response}` - Success with voice list
    * `{:error, reason}` - API error
  """
  def list_voices(provider, opts \\ []) when provider in [:hume_ai, :custom_voice] do
    timeout_opts = build_timeout_opts(opts)

    provider_param =
      case provider do
        :hume_ai -> "HUME_AI"
        :custom_voice -> "CUSTOM_VOICE"
      end

    query_params =
      [{"provider", provider_param}]
      |> add_optional_param(opts, :page_number, "page_number")
      |> add_optional_param(opts, :page_size, "page_size")
      |> URI.encode_query()

    url = "v0/tts/voices?" <> query_params

    get(url, timeout_opts)
    |> case do
      {:ok, %Tesla.Env{status: 200, body: response_body}} ->
        case VoiceListResponse.changeset(response_body)
             |> Ecto.Changeset.apply_action(:parse_response) do
          {:ok, validated_response} ->
            {:ok, validated_response}

          {:error, changeset} ->
            {:error, "Schema validation failed: #{inspect(changeset.errors)}"}
        end

      {:error, reason} ->
        {:error, reason}

      {:ok, %Tesla.Env{status: status, body: body}} ->
        {:error, "HTTP #{status}: #{inspect(body)}"}
    end
  end

  @doc """
  Stream available voices from Hume API with automatic pagination.

  ## Parameters
    * `provider` - Required voice provider: `:hume_ai` or `:custom_voice`
    * `opts` - Optional parameters:
      * `:page_size` - Page size (default: 10)
      * Other options are passed through to the API call

  ## Returns
    Stream of individual voice structs
  """
  def stream_voices(provider, opts \\ []) when provider in [:hume_ai, :custom_voice] do
    stream_voices_paginated!(provider, opts)
  end

  @doc """
  Create a voice from a generation ID on Hume API.

  ## Parameters
    * `generation_id` - Generation ID from a TTS response
    * `name` - Name to give the voice
    * `opts` - Optional timeout parameters

  ## Returns
    * `{:ok, :created}` - Success
    * `{:error, reason}` - API error
  """
  def create_voice(generation_id, name, opts \\ [])
      when is_binary(generation_id) and is_binary(name) do
    timeout_opts = build_timeout_opts(opts)

    body = %{
      generation_id: generation_id,
      name: name
    }

    post("v0/tts/voices", body, timeout_opts)
    |> case do
      {:ok, %Tesla.Env{status: 200}} ->
        {:ok, :created}

      {:ok, %Tesla.Env{status: 201}} ->
        {:ok, :created}

      {:error, reason} ->
        {:error, reason}

      {:ok, %Tesla.Env{status: status, body: body}} ->
        {:error, "HTTP #{status}: #{inspect(body)}"}
    end
  end

  @doc """
  Delete a voice by name from Hume API.

  ## Parameters
    * `name` - Voice name to delete
    * `opts` - Optional timeout parameters

  ## Returns
    * `{:ok, :deleted}` - Success
    * `{:error, reason}` - API error
  """
  def delete_voice(name, opts \\ []) when is_binary(name) do
    timeout_opts = build_timeout_opts(opts)
    url = "v0/tts/voices?name=#{URI.encode(name)}"

    delete(url, timeout_opts)
    |> case do
      {:ok, %Tesla.Env{status: 200}} ->
        {:ok, :deleted}

      {:ok, %Tesla.Env{status: 204}} ->
        {:ok, :deleted}

      {:error, reason} ->
        {:error, reason}

      {:ok, %Tesla.Env{status: status, body: body}} ->
        {:error, "HTTP #{status}: #{inspect(body)}"}
    end
  end

  @doc """
  Get a temporary OAuth2 access token for Hume EVI.

  Uses client credentials flow with HTTP Basic Authentication.
  This token should be passed to the frontend instead of the API key
  for better security.

  ## Parameters
    * `opts` - Optional timeout parameters

  ## Returns
    * `{:ok, access_token}` - Success with access token string
    * `{:error, reason}` - Authentication or API error

  ## Example
      {:ok, token} = Hume.get_access_token()
      # Pass token to frontend JavaScript
  """
  def get_access_token(opts \\ []) do
    timeout_opts = build_timeout_opts(opts)

    # Build OAuth2 client with Basic Auth
    middleware = [
      {Tesla.Middleware.BaseUrl, "https://api.hume.ai"},
      {Tesla.Middleware.BasicAuth, %{username: api_key(), password: secret_key()}},
      {Tesla.Middleware.Headers, [{"Content-Type", "application/x-www-form-urlencoded"}]},
      {Tesla.Middleware.Retry, delay: 1000, max_retries: 3}
    ]

    finch_opts = [
      name: Japanese.Finch,
      connect_timeout: Keyword.get(timeout_opts, :connect_timeout, 20000),
      receive_timeout: Keyword.get(timeout_opts, :receive_timeout, 60000)
    ]

    oauth_client = Tesla.client(middleware, {Tesla.Adapter.Finch, finch_opts})

    # Make the OAuth2 token request with form-encoded body
    body = URI.encode_query(%{"grant_type" => "client_credentials"})

    Tesla.post(oauth_client, "/oauth2-cc/token", body)
    |> case do
      {:ok, %Tesla.Env{status: 200, body: body}} when is_binary(body) ->
        # Manually decode JSON response
        case JSON.decode(body) do
          {:ok, %{"access_token" => access_token}} ->
            {:ok, access_token}

          {:ok, decoded} ->
            {:error, "No access_token in response: #{inspect(decoded)}"}

          {:error, decode_error} ->
            {:error, "Failed to decode JSON: #{inspect(decode_error)}"}
        end

      {:error, reason} ->
        {:error, reason}

      {:ok, %Tesla.Env{status: status, body: body}} ->
        {:error, "HTTP #{status}: #{inspect(body)}"}
    end
  end

  def tts(utterances, context \\ nil, opts \\ []) when is_list(utterances) do
    body = %{
      utterances: utterances
      # I have no idea what this affects, true by default, but false seems more real sometimes?
      # split_utterances: false,
    }

    body =
      if context do
        body |> Map.put(:context, context)
      else
        body
      end

    timeout_opts = build_timeout_opts(opts)

    post("v0/tts", body, timeout_opts)
    |> case do
      {:ok,
       %Tesla.Env{
         status: 200,
         body: response_body
       }} ->
        case save_audio_files_to_temp_dir(response_body) do
          {:ok, tts_response} -> {:ok, tts_response}
          {:error, reason} -> {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}

      {:ok, %Tesla.Env{status: status, body: body}} ->
        {:error, "HTTP #{status}: #{inspect(body)}"}
    end
  end

  def save_audio_files_to_temp_dir(%{"generations" => generations, "request_id" => request_id}) do
    with {:ok, temp_dir} <- Briefly.create(type: :directory) do
      processed_generations =
        generations
        |> Enum.with_index()
        |> Enum.map(fn {generation, index} ->
          # Process main audio file
          main_audio_file_path =
            if main_audio = generation["audio"] do
              case Base.decode64(main_audio) do
                {:ok, decoded_audio} ->
                  filename = "#{request_id}_#{index}.mp3"
                  file_path = Path.join(temp_dir, filename)
                  File.write!(file_path, decoded_audio)
                  Logger.info("Saved main audio: #{file_path}")
                  file_path

                :error ->
                  Logger.error("Failed to decode main audio for request #{request_id}")
                  nil
              end
            else
              nil
            end

          # Process snippet audio files
          processed_snippets =
            if snippets = generation["snippets"] do
              snippets
              |> List.flatten()
              |> Enum.map(fn snippet ->
                if audio = snippet["audio"] do
                  snippet_id = snippet["id"] || snippet["generation_id"]

                  case Base.decode64(audio) do
                    {:ok, decoded_audio} ->
                      filename = "#{snippet_id}.mp3"
                      file_path = Path.join(temp_dir, filename)
                      File.write!(file_path, decoded_audio)
                      Logger.info("Saved snippet audio: #{file_path}")

                      %{
                        id: snippet["id"],
                        generation_id: snippet["generation_id"],
                        audio_file_path: file_path
                      }

                    :error ->
                      Logger.error("Failed to decode audio for snippet #{snippet_id}")
                      nil
                  end
                else
                  nil
                end
              end)
              |> Enum.reject(&is_nil/1)
            else
              []
            end

          if main_audio_file_path do
            %{
              audio_file_path: main_audio_file_path,
              snippets: processed_snippets
            }
          else
            nil
          end
        end)
        |> Enum.reject(&is_nil/1)

      # Create response data for schema validation
      response_data = %{
        request_id: request_id,
        generations: processed_generations
      }

      # Validate using schema
      case TtsResponse.changeset(response_data) |> Ecto.Changeset.apply_action(:parse_response) do
        {:ok, validated_response} -> {:ok, validated_response}
        {:error, changeset} -> {:error, "Schema validation failed: #{inspect(changeset.errors)}"}
      end
    else
      {:error, reason} -> {:error, "Failed to create temp directory: #{inspect(reason)}"}
    end
  end

  def save_audio_files_to_temp_dir(_response) do
    {:error, "No audio data found in response"}
  end

  def get(url, opts \\ []) do
    Tesla.get(client(opts), url)
  end

  def post(url, body, opts \\ []) when is_map(body) do
    Tesla.post(client(opts), url, body)
  end

  def delete(url, opts \\ []) do
    Tesla.delete(client(opts), url)
  end

  defp build_timeout_opts(opts) do
    connect_timeout = Keyword.get(opts, :connect_timeout, 20000)
    receive_timeout = Keyword.get(opts, :receive_timeout, 240000)

    [connect_timeout: connect_timeout, receive_timeout: receive_timeout]
  end

  defp add_optional_param(query_params, opts, opt_key, param_name) do
    case Keyword.get(opts, opt_key) do
      nil -> query_params
      value -> query_params ++ [{param_name, to_string(value)}]
    end
  end

  defp stream_voices_paginated!(provider, opts) do
    page_size = Keyword.get(opts, :page_size, 10)

    Stream.unfold({0, true}, fn
      # Stop when no more pages
      {_page_number, false} ->
        nil

      # Fetch next page
      {page_number, _has_more} ->
        page_opts = Keyword.merge(opts, page_number: page_number, page_size: page_size)

        case list_voices(provider, page_opts) do
          {:ok, voice_list_response} ->
            voices = voice_list_response.voices_page
            current_page = voice_list_response.page_number
            total_pages = voice_list_response.total_pages
            has_more = current_page < total_pages - 1
            {voices, {page_number + 1, has_more}}

          {:error, reason} ->
            require Logger
            Logger.error("Error streaming voices: #{inspect(reason)}")
            raise "Failed to fetch voices from Hume API: #{inspect(reason)}"
        end
    end)
    |> Stream.concat()
  end

  defp client(opts) do
    middleware = [
      {Tesla.Middleware.BaseUrl, "https://api.hume.ai"},
      {Tesla.Middleware.Headers, [{"X-Hume-Api-Key", api_key()}]},
      {Tesla.Middleware.JSON, engine: JSON},
      {Tesla.Middleware.Retry, delay: 1000, max_retries: 3}
    ]

    finch_opts = [
      name: Japanese.Finch,
      connect_timeout: Keyword.get(opts, :connect_timeout, 20000),
      receive_timeout: Keyword.get(opts, :receive_timeout, 60000)
    ]

    Tesla.client(middleware, {Tesla.Adapter.Finch, finch_opts})
  end

  def api_key do
    res = Keyword.fetch!(config(), :api_key)

    if !res do
      raise "HUME_API_KEY is not set!"
    end

    res
  end

  def secret_key do
    res = Keyword.fetch!(config(), :secret_key)

    if !res do
      raise "HUME_SECRET_KEY is not set!"
    end

    res
  end

  def config do
    Application.get_env(:japanese, __MODULE__, [])
  end
end
