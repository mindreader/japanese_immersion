defmodule JapaneseWeb.PageLive.Show do
  use JapaneseWeb, :live_view

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       show_translation: false,
       selected_text: nil,
       explaining: false,
       explanation: nil,
       explain_task: nil,
       translation_status: nil
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

      translation_status = Japanese.Translation.Service.get_status(page)

      socket =
        socket
        |> assign(:translation, translation)
        |> assign(:translation_status, translation_status)

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
  def handle_info({:translation_started, _payload}, socket) do
    {:noreply, assign(socket, :translation_status, :in_progress)}
  end

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
        |> assign(:translation_status, nil)

      {:noreply, socket}
    else
      _ ->
        {:noreply, socket}
    end
  end

  def handle_info({:translation_failed, %{reason: reason}}, socket) do
    {:noreply, assign(socket, :translation_status, {:error, reason})}
  end

  @impl Phoenix.LiveView
  def handle_info({ref, result}, socket) when is_reference(ref) do
    # Task completed successfully
    if explain_task_ref(socket) == ref do
      Process.demonitor(ref, [:flush])

      explanation =
        case result do
          {:ok, text} ->
            # Parse markdown to HTML
            case Earmark.as_html(text) do
              {:ok, html, _messages} -> html
              {:error, _html, _messages} -> text
            end

          {:error, error_message} ->
            error_message
        end

      {:noreply,
       socket
       |> assign(:explaining, false)
       |> assign(:explain_task, nil)
       |> assign(:explanation, explanation)}
    else
      {:noreply, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_info({:DOWN, ref, :process, _pid, reason}, socket) do
    # Task crashed or was killed
    if explain_task_ref(socket) == ref do
      {:noreply,
       socket
       |> assign(:explaining, false)
       |> assign(:explain_task, nil)
       |> assign(:explanation, "Failed to generate explanation: #{inspect(reason)}")}
    else
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
  def handle_event("start_explain", %{"text" => selected_text}, socket) do
    # Spawn a supervised, non-linked task to get an explanation from the LLM
    # so a crash in the HTTP call doesn't take the LiveView process down.
    task =
      Task.Supervisor.async_nolink(Japanese.TaskSupervisor.name(), fn ->
        case Japanese.Translation.explain_text(selected_text) do
          {:error, reason} ->
            {:error, "Failed to generate explanation: #{inspect(reason)}"}

          explanation when is_binary(explanation) ->
            {:ok, explanation}
        end
      end)

    {:noreply,
     socket
     |> assign(:selected_text, selected_text)
     |> assign(:explaining, true)
     |> assign(:explain_task, task)}
  end

  @impl Phoenix.LiveView
  def handle_event("cancel_explain", _params, socket) do
    case socket.assigns.explain_task do
      %Task{} = task -> Task.Supervisor.terminate_child(Japanese.TaskSupervisor.name(), task.pid)
      nil -> :ok
    end

    {:noreply,
     socket
     |> assign(:explaining, false)
     |> assign(:explain_task, nil)}
  end

  @impl Phoenix.LiveView
  def handle_event("close_explanation_modal", _params, socket) do
    {:noreply, assign(socket, :explanation, nil)}
  end

  def handle_event("retry_translation", _params, socket) do
    page = socket.assigns.page
    Japanese.Translation.Service.clear_error(page)
    Japanese.Translation.Service.translate_page(page)
    {:noreply, assign(socket, :translation_status, :in_progress)}
  end

  defp explain_task_ref(socket) do
    case socket.assigns.explain_task do
      %Task{ref: ref} -> ref
      nil -> nil
    end
  end
end
