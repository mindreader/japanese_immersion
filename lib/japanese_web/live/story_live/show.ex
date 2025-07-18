defmodule JapaneseWeb.StoryLive.Show do
  use JapaneseWeb, :live_view

  alias Japanese.Corpus.Story

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok, assign(socket, new_page_text: nil, new_page_error: nil)}
  end

  defp manage_story_pubsub_subscription(old_story, new_story) do
    if new_story != old_story do
      if old_story do
        old_story |> Japanese.Events.Story.unsubscribe_story_pages()
      end

      new_story |> Japanese.Events.Story.subscribe_story_pages()
    end

    :ok
  end

  @impl Phoenix.LiveView
  def handle_params(%{"name" => name}, _, socket) do
    case Story.get_by_name(name) do
      {:ok, story} ->
        pages = Story.list_pages(story)
        old_story = socket.assigns[:story]

        if Phoenix.LiveView.connected?(socket) do
          manage_story_pubsub_subscription(old_story, story)
        end

        {:noreply,
         socket
         |> assign(:page_title, page_title(socket.assigns.live_action))
         |> assign(:story, story)
         |> assign(:pages, pages)
         |> assign(:edit_page_modal, false)
         |> assign(:new_page_modal, false)
         |> assign(:new_page_text, nil)
         |> assign(:new_page_error, nil)}

      {:error, :not_found} ->
        {:noreply,
         socket
         |> put_flash(:error, "Story #{name} not found.")
         |> push_patch(to: "/stories")}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("edit_page", %{"number" => number}, socket) do
    with {page_number, ""} <- Integer.parse(number),
         page when not is_nil(page) <-
           Enum.find(socket.assigns.pages, &(&1.number == page_number)),
         {:ok, japanese_text} <- Japanese.Corpus.Page.get_japanese_text(page) do
      {:noreply,
       socket
       |> assign(:edit_page_modal, true)
       |> assign(:edit_page_text, japanese_text)
       |> assign(:edit_page_error, nil)
       |> assign(:edit_page, page)}
    else
      _ ->
        {:noreply, put_flash(socket, :error, "Could not load page for editing.")}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("add_page", _params, socket) do
    {:noreply,
     socket
     |> assign(:new_page_modal, true)
     |> assign(:new_page_text, nil)
     |> assign(:new_page_error, nil)}
  end

  @impl Phoenix.LiveView
  def handle_event("create_page", %{"japanese_text" => text}, socket) do
    text = String.trim(text || "")

    if text == "" do
      {:noreply, assign(socket, new_page_error: "Text can't be blank")}
    else
      case Story.add_japanese_page(socket.assigns.story, text) do
        {:ok, page} ->
          page |> Japanese.Translation.Service.translate_page()
          pages = Story.list_pages(socket.assigns.story)

          {:noreply,
           socket
           |> assign(:page_title, page_title(socket.assigns.live_action))
           |> assign(:pages, pages)
           |> assign(:edit_page_modal, false)
           |> assign(:new_page_modal, false)
           |> assign(:new_page_text, nil)
           |> assign(:new_page_error, nil)
           |> push_patch(to: ~p"/stories/#{socket.assigns.story.name}")}

        {:error, reason} ->
          {:noreply, assign(socket, new_page_error: inspect(reason))}
      end
    end
  end

  @impl Phoenix.LiveView
  def handle_event("delete_page", %{"number" => number_str}, socket) do
    with {number, ""} <- Integer.parse(number_str),
         {:ok, story} <- Map.fetch(socket.assigns, :story),
         page = %Japanese.Corpus.Page{number: number, story: story.name},
         :ok <- Japanese.Corpus.Page.delete(page) do
      pages = Japanese.Corpus.Story.list_pages(story)
      {:noreply, assign(socket, :pages, pages)}
    else
      :error ->
        {:noreply, put_flash(socket, :error, "Invalid page number.")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to delete page: #{inspect(reason)}")}

      _ ->
        {:noreply, put_flash(socket, :error, "Unexpected error deleting page.")}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("update_page", %{"japanese_text" => text}, socket) do
    text = String.trim(text || "")
    page = socket.assigns.edit_page

    if is_nil(page) or text == "" do
      {:noreply, assign(socket, edit_page_error: "Text can't be blank")}
    else
      case Japanese.Corpus.Page.update_japanese_text(page, text) do
        :ok ->
          Japanese.Translation.Service.translate_page(page)
          pages = Story.list_pages(socket.assigns.story)

          {:noreply,
           socket
           |> assign(:pages, pages)
           |> assign(:edit_page_modal, false)
           |> assign(:new_page_modal, false)
           |> assign(:edit_page_text, nil)
           |> assign(:edit_page_error, nil)
           |> assign(:edit_page, nil)
           |> push_patch(to: ~p"/stories/#{socket.assigns.story.name}")}

        {:error, reason} ->
          {:noreply, assign(socket, edit_page_error: inspect(reason))}
      end
    end
  end

  @impl Phoenix.LiveView
  def handle_info({:pages_updated, %{story: story_name}}, socket) do
    # Only reload if this is the current story
    if socket.assigns[:story] && socket.assigns.story.name == story_name do
      pages = Story.list_pages(socket.assigns.story)
      {:noreply, assign(socket, :pages, pages)}
    else
      {:noreply, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_info({JapaneseWeb.StoryLive.FormComponent, {:saved, story}}, socket) do
    pages = Story.list_pages(story)
    {:noreply,
     socket
     |> assign(:story, story)
     |> assign(:pages, pages)
     |> put_flash(:info, "Story renamed successfully")
     |> push_patch(to: ~p"/stories/#{story.name}")}
  end

  defp page_title(:show), do: "Show Story"
  defp page_title(:edit), do: "Edit Story"
  defp page_title(:add), do: "Add Page"
end
