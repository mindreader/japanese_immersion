defmodule JapaneseWeb.PageLive.Show do
  use JapaneseWeb, :live_view

  alias Japanese.Corpus.Story

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"name" => name, "page" => page_param}, _, socket) do
    with {page_number, ""} <- Integer.parse(page_param),
         {:ok, story} <- Story.get_by_name(name),
         pages <- Story.list_pages(story),
         page <- Enum.find(pages, &(&1.number == page_number)),
         true <- not is_nil(page) do
      {:noreply,
       socket
       |> assign(:page_title, "Page #{page_number} of #{story.name}")
       |> assign(:story, story)
       |> assign(:page, page)}
    else
      _ ->
        {:noreply,
         socket
         |> put_flash(:error, "Page not found.")
         |> push_patch(to: ~p"/stories/#{name}")}
    end
  end
end
