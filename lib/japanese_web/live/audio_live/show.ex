defmodule JapaneseWeb.AudioLive.Show do
  use JapaneseWeb, :live_view

  alias Japanese.Corpus.{Audio, Page, Story}

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       snippet: nil,
       show_japanese: false,
       show_english: false,
       context: nil,
       error: nil
     )}
  end

  @impl Phoenix.LiveView
  def handle_params(%{"story" => story_name, "page_number" => page_num}, _uri, socket) do
    with {page_number, ""} <- Integer.parse(page_num),
         {:ok, story} <- Story.get_by_name(story_name),
         {:ok, page} <- Story.get_page(story, page_number) do
      socket =
        socket
        |> assign(:context, {:page, page})
        |> assign(:page_title, "Audio Practice - #{story_name} Page #{page_number}")
        |> load_random_snippet()

      {:noreply, socket}
    else
      _ ->
        {:noreply,
         socket
         |> put_flash(:error, "Page not found")
         |> push_navigate(to: ~p"/stories")}
    end
  end

  @impl Phoenix.LiveView
  def handle_params(%{"story" => story_name}, _uri, socket) do
    case Story.get_by_name(story_name) do
      {:ok, story} ->
        socket =
          socket
          |> assign(:context, {:story, story})
          |> assign(:page_title, "Audio Practice - #{story_name}")
          |> load_random_snippet()

        {:noreply, socket}

      {:error, :not_found} ->
        {:noreply,
         socket
         |> put_flash(:error, "Story not found")
         |> push_navigate(to: ~p"/stories")}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("reveal_japanese", _params, socket) do
    {:noreply, assign(socket, :show_japanese, true)}
  end

  @impl Phoenix.LiveView
  def handle_event("reveal_english", _params, socket) do
    {:noreply, assign(socket, :show_english, true)}
  end

  @impl Phoenix.LiveView
  def handle_event("next_snippet", _params, socket) do
    socket =
      socket
      |> assign(:show_japanese, false)
      |> assign(:show_english, false)
      |> load_random_snippet()

    {:noreply, socket}
  end

  defp load_random_snippet(socket) do
    case socket.assigns.context do
      {:story, story} ->
        case Audio.get_random_snippet_with_audio(story) do
          {:ok, snippet} ->
            assign(socket, snippet: snippet, error: nil)

          {:error, :no_audio_found} ->
            assign(socket, snippet: nil, error: "No audio files found for this story")
        end

      {:page, page} ->
        case Audio.get_random_snippet_with_audio(page) do
          {:ok, snippet} ->
            assign(socket, snippet: snippet, error: nil)

          {:error, :no_audio_found} ->
            assign(socket, snippet: nil, error: "No audio files found for this page")
        end

      nil ->
        assign(socket, snippet: nil, error: "Context not set")
    end
  end

  defp audio_url(snippet) do
    # Extract story name and filename from audio_path
    # audio_path format: /path/to/corpus/{story}/audio/{filename}
    path_parts = Path.split(snippet.audio_path)

    # Find "audio" in the path and get the story name before it
    audio_index = Enum.find_index(path_parts, &(&1 == "audio"))

    if audio_index && audio_index > 0 do
      story = Enum.at(path_parts, audio_index - 1)
      filename = List.last(path_parts)
      ~p"/audio-files/#{story}/#{filename}"
    else
      # Fallback in case path structure is unexpected
      ""
    end
  end
end
