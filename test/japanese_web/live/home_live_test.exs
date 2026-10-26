defmodule JapaneseWeb.HomeLiveTest do
  use JapaneseWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  test "links to each mode and shows the theme switch", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, ~s|#mode-stories[href="/stories"]|)
    assert has_element?(view, ~s|#mode-game[href="/game"]|)
    assert has_element?(view, ~s|#mode-drill[href="/drill"]|)

    for theme <- ~w(light dark system) do
      assert has_element?(view, "#theme-toggle button.theme-opt-#{theme}")
    end
  end

  test "the stories list leads back home", %{conn: conn} do
    Mimic.stub(Japanese.Corpus, :list_stories, fn -> [] end)
    {:ok, view, _html} = live(conn, ~p"/stories")
    assert has_element?(view, ~s|a[href="/"]|, "Back to home")
  end
end
