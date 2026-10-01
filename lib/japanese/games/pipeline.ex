defmodule Japanese.Games.Pipeline do
  @moduledoc """
  Turns one screenshot image into study text: Google Vision OCR, then one
  Claude call that arranges the OCR into sections with readings and
  meanings (`Japanese.Translation.transcribe_screenshot/3`), then the code
  clean-ups in `Japanese.Games.Transcript`.

  The image only ever lives in memory here; nothing is written to disk but
  the resulting `Japanese.Games.Shot`.
  """

  require Logger

  alias Japanese.Games.{Shot, Transcript, Vision}
  alias Japanese.Translation

  @doc """
  Processes an image for a shot and returns the finished shot (status
  `:done`), or an error. Does not save; see `Japanese.Games.Processor`.

  A screen with no text at all skips the Claude call.
  """
  @spec run(Shot.t(), binary(), String.t()) :: {:ok, Shot.t()} | {:error, term()}
  def run(%Shot{} = shot, image, media_type \\ "image/jpeg") do
    with {:ok, ocr} <- Vision.annotate(image) do
      if ocr.lines == [] do
        {:ok,
         finish(shot, %{description: "no text found", kind: "other", pointer: nil, sections: []},
           ocr_text: ocr.text
         )}
      else
        transcribe(shot, image, media_type, ocr)
      end
    end
  end

  defp transcribe(shot, image, media_type, ocr) do
    started = System.monotonic_time(:millisecond)

    with {:ok, reply} <-
           Translation.transcribe_screenshot(image, media_type, Vision.format_lines(ocr.lines)),
         {:ok, transcript} <- Transcript.parse(reply, ocr.text) do
      Logger.info(
        "Game shot #{shot.id} transcribed in #{System.monotonic_time(:millisecond) - started}ms: " <>
          inspect(transcript.description)
      )

      {:ok, finish(shot, transcript, ocr_text: ocr.text, model: Translation.model(:screenshot))}
    end
  end

  defp finish(%Shot{} = shot, transcript, opts) do
    %Shot{
      shot
      | status: :done,
        error: nil,
        description: transcript.description,
        kind: transcript.kind,
        pointer: transcript.pointer,
        sections: transcript.sections,
        ocr_text: Keyword.get(opts, :ocr_text),
        model: Keyword.get(opts, :model),
        processed_at: DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_iso8601()
    }
  end
end
