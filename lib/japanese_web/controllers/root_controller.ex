defmodule JapaneseWeb.RootController do
  use JapaneseWeb, :controller

  def home(conn, _params) do
    redirect(conn, to: ~p"/stories")
  end
end
