defmodule Japanese.Games.DeckTest do
  use ExUnit.Case, async: true

  alias Japanese.Games.{Deck, DeckWatcher, Processor, Shot}

  test "picks the first online steamdeck peer by name" do
    status = %{
      "Peer" => %{
        "a" => %{
          "DNSName" => "steamdeckz.tail.ts.net.",
          "Online" => true,
          "TailscaleIPs" => ["100.1.1.3", "fd7a::3"]
        },
        "b" => %{
          "DNSName" => "steamdeckprime.tail.ts.net.",
          "Online" => true,
          "TailscaleIPs" => ["fd7a::2", "100.1.1.2"]
        },
        "c" => %{
          "DNSName" => "steamdeckold.tail.ts.net.",
          "Online" => false,
          "TailscaleIPs" => ["100.1.1.4"]
        },
        "d" => %{
          "DNSName" => "oldpad.tail.ts.net.",
          "Online" => true,
          "TailscaleIPs" => ["100.1.1.5"]
        }
      }
    }

    assert {:ok, %Deck{name: "steamdeckprime", address: "100.1.1.2"}} =
             Deck.pick(status, "steamdeck")

    assert {:error, :no_deck} = Deck.pick(%{"Peer" => %{}}, "steamdeck")
    assert {:error, :no_deck} = Deck.pick(%{}, "steamdeck")
  end

  test "ssh args force the tailnet address and end with the command" do
    args = Deck.ssh_args(%Deck{name: "steamdeckprime", address: "100.1.1.2"}, "echo hi")
    assert "HostName=100.1.1.2" in args
    assert "BatchMode=yes" in args
    assert List.last(args) == "echo hi"
    assert Enum.at(args, -2) == "deck@steamdeckprime"
  end

  test "shell_quote survives single quotes" do
    assert Deck.shell_quote("a'b") == "'a'\\''b'"
  end

  test "the remote script has no single quotes (it is sent as one ssh argument)" do
    refute DeckWatcher.remote_script() =~ "'"
  end

  test "parse_remote_path accepts screenshots and skips thumbnails" do
    base = "/home/deck/.local/share/Steam/userdata/42/760/remote/1718570"

    assert {:ok, "1718570", "20261001083845_1.jpg"} =
             Processor.parse_remote_path(base <> "/screenshots/20261001083845_1.jpg")

    assert :error =
             Processor.parse_remote_path(base <> "/screenshots/thumbnails/20261001083845_1.jpg")

    assert :error = Processor.parse_remote_path(base <> "/screenshots/notes.txt")
  end

  describe "catch_up/4" do
    @base "/r/1718570/screenshots/"
    defp paths(names), do: Enum.map(names, &(@base <> &1 <> ".jpg"))

    test "first connection takes only the latest few" do
      all = paths(~w(20261001080000_1 20261001090000_1 20261001070000_1 20261001100000_1))

      assert DeckWatcher.catch_up(all, [], "steamdeckprime", 2) ==
               paths(~w(20261001090000_1 20261001100000_1))
    end

    test "later connections take everything newer than the newest known shot for that deck" do
      all = paths(~w(20261001080000_1 20261001090000_1 20261001090000_2 20261001100000_1))

      known = [
        Shot.new("steamdeckprime", "1718570", "20261001090000_1.jpg"),
        Shot.new("other", "1", "20261001095000_1.jpg")
      ]

      assert DeckWatcher.catch_up(all, known, "steamdeckprime", 2) ==
               paths(~w(20261001090000_2 20261001100000_1))
    end
  end
end
