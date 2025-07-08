defmodule JapaneseWeb.StoryLive.Show do
  use JapaneseWeb, :live_view

  alias Japanese.Corpus.Story

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, new_page_text: nil, new_page_error: nil)}
  end

  @impl true
  def handle_params(%{"name" => name}, _, socket) do
    case Story.get_by_name(name) do
      {:ok, story} ->
        pages = Story.list_pages(story)
        {:noreply,
         socket
         |> assign(:page_title, page_title(socket.assigns.live_action))
         |> assign(:story, story)
         |> assign(:pages, pages)
         |> assign(:new_page_text, nil)
         |> assign(:new_page_error, nil)}
      {:error, :not_found} ->
        {:noreply,
         socket
         |> put_flash(:error, "Story #{name} not found.")
         |> push_patch(to: "/stories")}
    end
  end

  @impl true
  def handle_params(%{"name" => name, "page" => page}, _, socket) do
    case Integer.parse(page) do
      {selected_page, ""} ->
        case Story.get_by_name(name) do
          {:ok, story} ->
            pages = Story.list_pages(story)
            {:noreply,
             socket
             |> assign(:page_title, "Show Page #{selected_page}")
             |> assign(:story, story)
             |> assign(:pages, pages)
             |> assign(:selected_page, selected_page)}
          {:error, :not_found} ->
            {:noreply,
             socket
             |> put_flash(:error, "Story \\#{name} not found.")
             |> push_patch(to: "/stories")}
        end
      _ ->
        {:noreply,
         socket
         |> put_flash(:error, "Invalid page number.")
         |> push_patch(to: ~p"/stories/#{name}")}
    end
  end

  @impl true
  def handle_event("add_page", _params, socket) do
    {:noreply,
     socket
     |> assign(:live_action, :new_page)
     |> assign(:new_page_text, nil)
     |> assign(:new_page_error, nil)}
  end

  @impl true
  def handle_event("create_page", %{"japanese_text" => text}, socket) do
    text = String.trim(text || "")
    if text == "" do
      {:noreply, assign(socket, new_page_error: "Text can't be blank")}
    else
      case Story.add_japanese_page(socket.assigns.story, text) do
        {:ok, _page} ->
          pages = Story.list_pages(socket.assigns.story)
          {:noreply,
           socket
           |> assign(:pages, pages)
           |> assign(:live_action, nil)
           |> assign(:new_page_text, nil)
           |> assign(:new_page_error, nil)}
        {:error, reason} ->
          {:noreply, assign(socket, new_page_error: inspect(reason))}
      end
    end
  end

  defp page_title(:show), do: "Show Story"
  defp page_title(:edit), do: "Edit Story"
end
