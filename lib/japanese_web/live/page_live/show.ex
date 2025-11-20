defmodule JapaneseWeb.PageLive.Show do
  require Logger
  use JapaneseWeb, :live_view

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       show_translation: false,
       selected_text: nil,
       explaining: false,
       explanation: nil,
       explain_task_ref: nil
     )}
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

  @impl Phoenix.LiveView
  def handle_event("start_explain", _params, socket) do
    selected_text = socket.assigns.selected_text

    # Spawn async task to simulate explanation generation
    task =
      Task.async(fn ->
        Process.sleep(4000)
        # Placeholder explanation - will be replaced with LLM call later
        "This is a placeholder explanation for: #{selected_text}"
      end)

    {:noreply,
     socket
     |> assign(:explaining, true)
     |> assign(:explain_task_ref, task.ref)}
  end

  @impl Phoenix.LiveView
  def handle_event("cancel_explain", _params, socket) do
    # Cancel the task if it exists
    if socket.assigns.explain_task_ref do
      # We can't easily cancel a Task.async, but we can ignore its result
      # by removing the ref from state
    end

    {:noreply,
     socket
     |> assign(:explaining, false)
     |> assign(:explain_task_ref, nil)}
  end

  @impl Phoenix.LiveView
  def handle_event("close_explanation_modal", _params, socket) do
    {:noreply, assign(socket, :explanation, nil)}
  end

  @impl Phoenix.LiveView
  def handle_info({ref, result}, socket) when is_reference(ref) do
    # Task completed successfully
    if ref == socket.assigns.explain_task_ref do
      Process.demonitor(ref, [:flush])

      {:noreply,
       socket
       |> assign(:explaining, false)
       |> assign(:explain_task_ref, nil)
       |> assign(:explanation, result)}
    else
      {:noreply, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_info({:DOWN, ref, :process, _pid, _reason}, socket) do
    # Task crashed or was killed
    if ref == socket.assigns.explain_task_ref do
      {:noreply,
       socket
       |> assign(:explaining, false)
       |> assign(:explain_task_ref, nil)}
    else
      {:noreply, socket}
    end
  end
end
