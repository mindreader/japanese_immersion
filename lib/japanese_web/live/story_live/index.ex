defmodule JapaneseWeb.StoryLive.Index do
  use JapaneseWeb, :live_view

  alias Japanese.Corpus
  alias Japanese.Corpus.Story

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    socket =
      socket
      |> Phoenix.LiveView.stream_configure(:stories,
        dom_id: fn %Story{name: name} -> "story-#{name}" end
      )
      |> assign(:generating_story_audio, %{})
      |> assign(:voice_selection_story, nil)

    {:ok, stream(socket, :stories, Corpus.list_stories())}
  end

  @impl Phoenix.LiveView
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"name" => name}) do
    socket
    |> assign(:page_title, "Edit Story")
    |> assign(:story, %Story{name: name})
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Story")
    |> assign(:story, %Story{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Stories")
    |> assign(:story, nil)
  end

  @impl Phoenix.LiveView
  def handle_info({JapaneseWeb.StoryLive.FormComponent, {:saved, story}}, socket) do
    {:noreply, stream_insert(socket, :stories, story)}
  end

  @impl Phoenix.LiveView
  def handle_info({ref, result}, socket) when is_reference(ref) do
    # Find which story this task belongs to
    story_name =
      Enum.find_value(socket.assigns.generating_story_audio, fn {name, task_ref} ->
        if task_ref == ref, do: name
      end)

    if story_name do
      Process.demonitor(ref, [:flush])

      socket =
        case result do
          {:ok, audio_files} ->
            put_flash(
              socket,
              :info,
              "Generated #{length(audio_files)} audio files for story '#{story_name}'"
            )

          {:error, reason} ->
            put_flash(
              socket,
              :error,
              "Failed to generate audio for story '#{story_name}': #{inspect(reason)}"
            )
        end

      {:noreply,
       assign(
         socket,
         :generating_story_audio,
         Map.delete(socket.assigns.generating_story_audio, story_name)
       )}
    else
      {:noreply, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_info({:DOWN, ref, :process, _pid, _reason}, socket) when is_reference(ref) do
    # Find which story this task belongs to
    story_name =
      Enum.find_value(socket.assigns.generating_story_audio, fn {name, task_ref} ->
        if task_ref == ref, do: name
      end)

    if story_name do
      {:noreply,
       socket
       |> put_flash(:error, "Audio generation failed unexpectedly for story '#{story_name}'")
       |> assign(
         :generating_story_audio,
         Map.delete(socket.assigns.generating_story_audio, story_name)
       )}
    else
      {:noreply, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("delete", %{"id" => name}, socket) do
    case Story.get_by_name(name) do
      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "Story not found")}

      {:ok, story} ->
        case Story.delete(story) do
          :ok ->
            {:noreply, stream_delete(socket, :stories, story)}

          {:error, reason} ->
            {:noreply, put_flash(socket, :error, "Failed to delete story: #{inspect(reason)}")}
        end
    end
  end

  @impl Phoenix.LiveView
  def handle_event("show_story_voice_selection", %{"story" => name}, socket) do
    {:noreply, assign(socket, :voice_selection_story, name)}
  end

  @impl Phoenix.LiveView
  def handle_event("generate_story_audio", %{"story" => name, "voice" => voice_str}, socket) do
    case Story.get_by_name(name) do
      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "Story not found")}

      {:ok, story} ->
        voice = String.to_existing_atom(voice_str)

        task =
          Task.async(fn ->
            Japanese.Corpus.Audio.generate_for_story(story, voice, skip_existing: true)
          end)

        {:noreply,
         socket
         |> assign(
           :generating_story_audio,
           Map.put(socket.assigns.generating_story_audio, name, task.ref)
         )
         |> assign(:voice_selection_story, nil)}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("close_story_voice_modal", _params, socket) do
    {:noreply, assign(socket, :voice_selection_story, nil)}
  end
end
