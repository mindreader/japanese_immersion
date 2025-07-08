defmodule JapaneseWeb.StoryLive.Show do
  use JapaneseWeb, :live_view

  alias Japanese.Corpus.Story

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
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
         |> assign(:pages, pages)}
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

  defp page_title(:show), do: "Show Story"
  defp page_title(:edit), do: "Edit Story"
end
