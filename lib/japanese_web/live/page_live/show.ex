defmodule JapaneseWeb.PageLive.Show do
  require Logger
  use JapaneseWeb, :live_view

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok, assign(socket, show_translation: false, selected_text: nil)}
  end

  @impl Phoenix.LiveView
  @spec handle_params(map(), any(), any()) :: {:noreply, map()}
  def handle_params(%{"name" => name, "page" => page_param}, _uri, socket) do
    with {page_number, ""} <- Integer.parse(page_param),
         {:ok, story} <- Japanese.Corpus.Story.get_by_name(name),
         {:ok, page} <- Japanese.Corpus.Story.get_page(story, page_number) do
      if connected?(socket) do
        old_page = socket.assigns[:page]
        manage_pubsub_subscription(old_page, page)
      end

      socket =
        socket
        |> assign(:page_title, "Page #{page_number} of #{story.name}")
        |> assign(:story, story)
        |> assign(:page, page)

      translation =
        case Japanese.Corpus.Page.get_translation(page) do
          {:ok, content} -> content
          _ -> nil
        end

      socket = assign(socket, :translation, translation)

      {:noreply, socket}
    else
      _ ->
        {:noreply,
         socket
         |> put_flash(:error, "Page not found.")
         |> push_navigate(to: ~p"/stories/#{name}")}
    end
  end

  defp manage_pubsub_subscription(old_page, new_page) do
    if old_page != new_page do
      if old_page do
        old_page |> Japanese.Events.Page.unsubscribe_page()
      end

      new_page |> Japanese.Events.Page.subscribe_page()
    end

    :ok
  end

  @impl Phoenix.LiveView
  def handle_info({:translation_finished, %{story: story, page: page_number}}, socket) do
    # Refetch story and page, then update assigns
    with {:ok, story} <- Japanese.Corpus.Story.get_by_name(story),
         {:ok, page} <- Japanese.Corpus.Story.get_page(story, page_number) do
      translation =
        case Japanese.Corpus.Page.get_translation(page) do
          {:ok, content} -> content
          _ -> nil
        end

      socket =
        socket
        |> assign(:story, story)
        |> assign(:page, page)
        |> assign(:translation, translation)

      {:noreply, socket}
    else
      _ ->
        {:noreply, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("text_selected", %{"text" => text}, socket) do
    {:noreply, assign(socket, :selected_text, text)}
  end

  @impl Phoenix.LiveView
  def handle_event("clear_selection", _params, socket) do
    {:noreply, assign(socket, :selected_text, nil)}
  end

  @impl Phoenix.LiveView
  def handle_event("demo_action", _params, socket) do
    Logger.info("Demo action triggered! Selected text: #{inspect(socket.assigns.selected_text)}")
    {:noreply, socket}
  end
end
