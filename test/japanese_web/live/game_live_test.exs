defmodule JapaneseWeb.GameLiveTest do
  use JapaneseWeb.ConnCase, async: false
  use Mimic
  import Phoenix.LiveViewTest
  import Japanese.GamesCase, only: [eventually: 1]

  alias Japanese.Games
  alias Japanese.Games.Shot

  setup :set_mimic_global
  setup :verify_on_exit!

  setup do
    dir = Briefly.create!(directory: true)
    Application.put_env(:japanese, Japanese.Games, dir: dir)
    on_exit(fn -> Application.delete_env(:japanese, Japanese.Games) end)
    :ok
  end

  defp done_shot(file, description) do
    shot = %Shot{
      Shot.new("steamdeckprime", "1718570", file, game: "ASTLIBRA")
      | status: :done,
        description: description,
        sections: [
          %{
            "name" => "items",
            "labels" => ["EQUIP"],
            "focused_label" => "EQUIP",
            "lines" => [
              %{"ja" => "銅の槍", "reading" => "どうのやり", "en" => "Copper Spear", "focused" => true}
            ]
          }
        ]
    }

    {:ok, shot} = Games.save_shot(shot)
    shot
  end

  test "empty state", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/game")
    assert html =~ "No screenshots yet"
  end

  test "shows the newest shot with toggleable text, and steps back", %{conn: conn} do
    old = done_shot("20261001080000_1.jpg", "older menu")
    _new = done_shot("20261001090000_1.jpg", "equipment menu")

    {:ok, view, html} = live(conn, ~p"/game")
    assert html =~ "equipment menu"
    assert html =~ "銅の槍"
    assert has_element?(view, ".game-text .g-kana", "どうのやり")
    assert has_element?(view, ".game-text .g-eng", "Copper Spear")
    assert has_element?(view, ".game-text .tr-ja", "銅の槍")
    assert has_element?(view, "#toggle-english")
    refute has_element?(view, "#toggle-japanese")
    refute has_element?(view, "#newer-shot")

    view |> element("#older-shot") |> render_click()
    assert_patch(view, ~p"/game/#{old.id}")
    assert render(view) =~ "older menu"
  end

  test "a new screenshot shows a banner instead of moving the page", %{conn: conn} do
    old = done_shot("20261001080000_1.jpg", "older menu")
    {:ok, view, _html} = live(conn, ~p"/game")

    pending = Shot.new("steamdeckprime", "1718570", "20261001100000_1.jpg")
    {:ok, _} = Games.save_shot(pending)
    Games.broadcast({:shot_added, pending})

    eventually(fn -> has_element?(view, "#arrived-banner", "waiting") end)
    assert render(view) =~ "older menu"

    done = %Shot{pending | status: :done, description: "new dialogue", sections: []}
    {:ok, _} = Games.save_shot(done)
    Games.broadcast({:shot_updated, done})
    eventually(fn -> has_element?(view, "#arrived-banner", "new dialogue") end)
    assert has_element?(view, "#shot-description", "older menu")

    view |> element("#arrived-banner a", "View") |> render_click()
    assert_patch(view, ~p"/game/#{pending.id}")
    assert has_element?(view, "#shot-description", "new dialogue")
    refute has_element?(view, "#arrived-banner")
    assert old.id != pending.id
  end

  test "an empty page switches to the first screenshot", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/game")
    pending = Shot.new("steamdeckprime", "1718570", "20261001100000_1.jpg")
    {:ok, _} = Games.save_shot(pending)
    Games.broadcast({:shot_added, pending})
    assert_patch(view, ~p"/game/#{pending.id}")
    assert render(view) =~ "Reading the screenshot"
  end

  test "an unknown shot redirects to the latest", %{conn: conn} do
    assert {:error, {:live_redirect, %{to: "/game"}}} = live(conn, ~p"/game/nope")
  end

  test "explain works on selected text", %{conn: conn} do
    done_shot("20261001090000_1.jpg", "equipment menu")
    Mimic.stub(Japanese.Translation, :explain_text, fn "銅の槍" -> "a **spear**" end)

    {:ok, view, _html} = live(conn, ~p"/game")
    render_hook(view, "text_selected", %{"text" => "銅の槍", "context" => "銅の槍"})
    render_click(view, "start_explain", %{"text" => "銅の槍"})
    eventually(fn -> render(view) =~ "<strong>spear</strong>" end)
  end
end
