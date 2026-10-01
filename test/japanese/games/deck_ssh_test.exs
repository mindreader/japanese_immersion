defmodule Japanese.Games.DeckSshTest do
  # Not async: these change global state (the Deck app env, $HOME).
  use ExUnit.Case, async: false

  alias Japanese.Games.Deck

  describe "ssh without a home directory" do
    setup do
      saved = Application.get_env(:japanese, Deck)
      on_exit(fn -> Application.put_env(:japanese, Deck, saved || []) end)
    end

    test "host key checking is off and nothing is written to known_hosts" do
      args = Deck.ssh_args(%Deck{name: "steamdeckprime", address: "100.1.1.2"}, "echo hi")

      for option <- [
            "StrictHostKeyChecking=no",
            "UserKnownHostsFile=/dev/null",
            "LogLevel=ERROR",
            "BatchMode=yes"
          ] do
        assert option in args
      end
    end

    test "the configured key (DECK_SSH_KEY) is passed explicitly" do
      Application.put_env(:japanese, Deck,
        ssh_key: "/run/credentials/japanese.service/deck_ssh_key"
      )

      args = Deck.ssh_args(%Deck{name: "steamdeckprime", address: "100.1.1.2"}, "echo hi")

      assert ["-i", "/run/credentials/japanese.service/deck_ssh_key", "-o", "IdentitiesOnly=yes"] ==
               Enum.drop_while(args, &(&1 != "-i")) |> Enum.take(4)
    end

    test "no key and no HOME doesn't raise" do
      Application.put_env(:japanese, Deck, ssh_key: nil)
      home = System.get_env("HOME")
      System.delete_env("HOME")

      try do
        assert is_list(Deck.ssh_args(%Deck{name: "d", address: "100.1.1.2"}, "true"))
      after
        if home, do: System.put_env("HOME", home)
      end
    end
  end
end
