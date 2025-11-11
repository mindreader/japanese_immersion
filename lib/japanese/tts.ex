defmodule Japanese.TTS do
  require Logger

  @doc """
  Generate text-to-speech audio using a specific voice from the database.

  This function requires a HumeVoice schema to be specified and generates TTS with that voice.
  Long scripts are split into utterance-sized chunks (preferring paragraphs, then sentences)
  before being sent to the provider.

  ## Parameters
    * `text_input` - Text to convert to speech:
      * `string` - Single text to convert
      * `[string]` - List of texts to convert
    * `hume_voice` - Required HumeVoice schema from database
    * `opts` - Optional parameters passed to TTS API
      * All other options are forwarded to the provider call

  ## Returns
    * `{:ok, tts_response}` - Success with TTS response and audio files
    * `{:error, reason}` - TTS generation failed

  ## Examples
      iex> voice = Hume.find_voice("my-custom-voice") |> elem(1)
      iex> Hume.generate_tts("Hello world", voice)
      {:ok, %TtsResponse{...}}

      iex> Hume.generate_tts(["Hello", "How are you?"], voice)
      {:ok, %TtsResponse{...}}

      iex> Hume.generate_tts("Hello", voice, receive_timeout: 30000)
      {:ok, %TtsResponse{...}}
  """
  def generate_tts(text_input, hume_voice, opts \\ []) do
    utterances = build_utterances_with_hume_voice([text_input], hume_voice)

    case Japanese.Hume.tts(utterances, nil, opts) do
      {:ok, tts_response} ->
        Logger.info("TTS generation completed successfully")
        {:ok, tts_response}

      {:error, reason} ->
        Logger.error("TTS generation failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp build_utterances_with_hume_voice(texts, %{id: id, name: _name}) do
    texts
    |> Enum.with_index()
    |> Enum.map(fn {text, index} ->
      if index == 0 do
        # Apply voice to first utterance with new format
        %{
          text: text,
          voice: %{
            id: id,
            provider: :HUME_AI
          }
        }
      else
        %{text: text}
      end
    end)
  end

  def japanese_voices do
    [
      %{
        id: "e0d9aa34-a6d5-4892-803e-794b157ce1cb",
        name: "Akira"
      },
      %{
        id: "e5c30713-861d-476e-883a-fc0e1788f736",
        name: "Fumiko"
      },
      %{
        id: "964f54e6-b1f1-4934-8363-af5060ba6980",
        name: "Aiko"
      },
      %{
        id: "fb494627-7477-4a4c-9c34-2915b523da91",
        name: "Ken"
      },
      %{
        id: "550ac3b0-207b-463e-b3e6-af7ec98cbc3a",
        name: "Kana"
      },
      %{
        id: "35174c3f-e6d3-4b1d-9551-d13afae78e93",
        name: "Yuki"
      },
      %{
        id: "88fd5c2c-3de8-44b4-b014-66f46eaf8720",
        name: "Aya"
      },
      %{
        id: "9233b2d9-7ccf-46bf-b5de-531491b9b400",
        name: "Nami"
      }
    ]
  end
end
