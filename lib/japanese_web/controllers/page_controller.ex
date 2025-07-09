defmodule JapaneseWeb.PageController do
  use JapaneseWeb, :controller
  alias Japanese.Corpus.Page

  def home(conn, _params) do
    redirect(conn, to: ~p"/stories")
  end

  def japanese(conn, %{"name" => name, "page" => page_num}) do
    page = %Page{number: String.to_integer(page_num), story: name}

    case Page.get_japanese_text(page) do
      {:ok, text} ->
        render(conn, :japanese, text: text, page: page)

      {:error, _} ->
        send_resp(conn, 404, "Could not load Japanese text.")
    end
  end
end
