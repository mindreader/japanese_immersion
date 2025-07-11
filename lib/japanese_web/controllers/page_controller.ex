defmodule JapaneseWeb.PageController do
  use JapaneseWeb, :controller
  alias Japanese.Corpus.{Page, Story}

  def home(conn, _params) do
    redirect(conn, to: ~p"/stories")
  end

  def japanese(conn, %{"name" => name, "page" => page_num}) do
    with {:ok, story} <- Story.get_by_name(name),
         {:page_number, {page_number, ""}} <- {:page_number, Integer.parse(page_num)},
         {:ok, page} <- Story.get_page(story, page_number),
         {:ok, text} <- Page.get_japanese_text(page) do
      render(conn, :japanese, text: text, page: page, story: name)
    else
      {:error, :not_found} ->
        send_resp(conn, 404, "Story or page not found.")

      {:page_number, :error} ->
        send_resp(conn, 404, "Invalid page number.")

      {:error, _} ->
        send_resp(conn, 404, "Could not load Japanese text.")
    end
  end
end
