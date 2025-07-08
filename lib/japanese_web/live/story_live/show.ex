defmodule JapaneseWeb.StoryLive.Show do
  use JapaneseWeb, :live_view

  alias Japanese.Corpus.Story

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => name}, _, socket) do
    case Story.get_by_name(name) do
      {:ok, story} ->
        {:noreply,
         socket
         |> assign(:page_title, page_title(socket.assigns.live_action))
         |> assign(:story, story)}
      {:error, :not_found} ->
        {:noreply,
         socket
         |> put_flash(:error, "Story #{name} not found.")
         |> push_patch(to: "/stories")}
    end
  end

  defp page_title(:show), do: "Show Story"
  defp page_title(:edit), do: "Edit Story"
end
