defmodule JapaneseWeb.PageLive.Show do
  use JapaneseWeb, :live_view

  alias Japanese.Corpus.Story

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  @spec handle_params(map(), any(), any()) :: {:noreply, map()}
  def handle_params(%{"name" => name, "page" => page_param}, _uri, socket) do
    action = socket.assigns.live_action
    with {page_number, ""} <- Integer.parse(page_param),
         {:ok, story} <- Story.get_by_name(name),
         pages <- Story.list_pages(story),
         page <- Enum.find(pages, &(&1.number == page_number)),
         true <- not is_nil(page) do
      socket =
        socket
        |> assign(:page_title, "Page #{page_number} of #{story.name}")
        |> assign(:story, story)
        |> assign(:page, page)
        |> assign(:view_mode, action)

      socket =
        if action |> IO.inspect(label: "action") == :japanese do
          case Japanese.Corpus.Page.get_japanese_text(page) do
            {:ok, text} -> assign(socket, :japanese_text, text)
            {:error, _} -> assign(socket, :japanese_text, nil)
          end
        else
          assign(socket, :japanese_text, nil)
        end

      {:noreply, socket}
    else
      _ ->
        {:noreply,
         socket
         |> put_flash(:error, "Page not found.")
         |> push_patch(to: ~p"/stories/#{name}")}
    end
  end
end
