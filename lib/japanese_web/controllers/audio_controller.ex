defmodule JapaneseWeb.AudioController do
  use JapaneseWeb, :controller
  alias Japanese.Corpus.StorageLayer

  def serve(conn, %{"story" => story, "filename" => filename}) do
    storage = StorageLayer.new()
    audio_path = Path.join([storage.working_directory, story, "audio", filename])

    if File.exists?(audio_path) do
      conn
      |> put_resp_content_type("audio/mpeg")
      |> send_file(200, audio_path)
    else
      send_resp(conn, 404, "Audio file not found")
    end
  end
end
