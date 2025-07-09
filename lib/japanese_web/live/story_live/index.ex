defmodule JapaneseWeb.StoryLive.Index do
  use JapaneseWeb, :live_view

  alias Japanese.Corpus
  alias Japanese.Corpus.Story

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    socket =
      socket
      |> Phoenix.LiveView.stream_configure(:stories,
        dom_id: fn %Japanese.Corpus.Story{name: name} -> "story-#{name}" end
      )

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
  def handle_event("delete", %{"id" => name}, socket) do
    story = %Story{name: name}
    :ok = Story.delete(story)
    {:noreply, stream_delete(socket, :stories, story)}
  end
end
