defmodule Japanese.Games.Deck do
  @moduledoc """
  Finding a Steam Deck on the tailnet and talking to it over SSH.

  A Deck is any tailnet peer whose name starts with `"steamdeck"` (so
  `steamdeckprime`, `steamdeck2`, ...) and is online. If several are, the
  first by name wins.

  SSH connects to the Deck's *name* with its tailnet address forced as
  `HostName`, so DNS is never needed and anything in `~/.ssh/config` for that
  name (key file, `HostKeyAlias`) still applies. `BatchMode` means a missing
  key or unknown host key fails immediately instead of waiting at a prompt.
  The keepalive options make a connection to a Deck that went to sleep die
  within ~30 seconds.

  Config (`config :japanese, Japanese.Games.Deck`):

    * `:name_prefix` — peer name prefix, default `"steamdeck"`
    * `:user` — SSH user, default `"deck"`
    * `:ssh_key` — private key to use; default `~/.ssh/steamdeck_ed25519` if it
      exists, otherwise ssh's own defaults (agent, config)
  """

  @enforce_keys [:name, :address]
  defstruct [:name, :address]

  @type t :: %__MODULE__{name: String.t(), address: String.t()}

  @doc """
  Looks for an online Deck in `tailscale status --json`.
  """
  @spec find() :: {:ok, t()} | {:error, :no_deck | :tailscale_unavailable | term()}
  def find do
    case System.find_executable("tailscale") do
      nil ->
        {:error, :tailscale_unavailable}

      tailscale ->
        case System.cmd(tailscale, ["status", "--json"], stderr_to_stdout: false) do
          {json, 0} ->
            with {:ok, status} <- Jason.decode(json), do: pick(status, name_prefix())

          {_, code} ->
            {:error, {:tailscale_exit, code}}
        end
    end
  end

  @doc """
  Picks an online Deck from a decoded `tailscale status --json` document.
  """
  @spec pick(map(), String.t()) :: {:ok, t()} | {:error, :no_deck}
  def pick(status, prefix) do
    status
    |> Map.get("Peer", %{})
    |> Map.values()
    |> Enum.filter(&(&1["Online"] == true))
    |> Enum.map(fn peer -> {peer_name(peer), ipv4(peer["TailscaleIPs"])} end)
    |> Enum.filter(fn {name, address} ->
      is_binary(address) and String.starts_with?(name, prefix)
    end)
    |> Enum.sort()
    |> case do
      [{name, address} | _] -> {:ok, %__MODULE__{name: name, address: address}}
      [] -> {:error, :no_deck}
    end
  end

  @doc """
  The `ssh` arguments to run `command` on the Deck (command last).
  """
  @spec ssh_args(t(), String.t()) :: [String.t()]
  def ssh_args(%__MODULE__{name: name, address: address}, command) do
    [
      "-T",
      "-o",
      "BatchMode=yes",
      "-o",
      "ConnectTimeout=5",
      "-o",
      "ServerAliveInterval=10",
      "-o",
      "ServerAliveCountMax=3",
      "-o",
      "HostName=#{address}"
    ] ++ key_args() ++ ["#{user()}@#{name}", command]
  end

  @doc """
  Path to the `ssh` executable.
  """
  @spec ssh() :: String.t()
  def ssh, do: System.find_executable("ssh") || "ssh"

  @doc """
  Runs a command on the Deck and returns its stdout.
  """
  @spec run(t(), String.t()) :: {:ok, binary()} | {:error, term()}
  def run(deck, command) do
    case System.cmd(ssh(), ssh_args(deck, command)) do
      {output, 0} -> {:ok, output}
      {output, code} -> {:error, {:ssh_exit, code, String.slice(output, 0, 200)}}
    end
  end

  @doc """
  Copies a file from the Deck into memory.
  """
  @spec fetch(t(), String.t()) :: {:ok, binary()} | {:error, term()}
  def fetch(deck, path) do
    case run(deck, "cat " <> shell_quote(path)) do
      {:ok, ""} -> {:error, :empty_file}
      other -> other
    end
  end

  @doc """
  The Steam name of an installed game, read from its app manifest on the
  Deck (internal storage or an SD card), or nil if it can't be found (e.g.
  a non-Steam shortcut).
  """
  @spec game_name(t(), String.t()) :: String.t() | nil
  def game_name(deck, appid) do
    if appid =~ ~r/^\d+$/ do
      manifest = "steamapps/appmanifest_#{appid}.acf"

      command =
        "grep -h -m1 '\"name\"' " <>
          "$HOME/.local/share/Steam/#{manifest} /run/media/*/#{manifest} " <>
          "/run/media/*/*/#{manifest} 2>/dev/null | head -n1"

      case run(deck, command) do
        {:ok, output} ->
          case Regex.run(~r/"name"\s+"(.+)"/, output) do
            [_, name] -> name
            _ -> nil
          end

        {:error, _} ->
          nil
      end
    end
  end

  @doc """
  Quotes a string for the remote POSIX shell.
  """
  @spec shell_quote(String.t()) :: String.t()
  def shell_quote(string), do: "'" <> String.replace(string, "'", "'\\''") <> "'"

  defp peer_name(peer) do
    case peer["DNSName"] do
      dns when is_binary(dns) and dns != "" -> dns |> String.split(".") |> hd()
      _ -> peer["HostName"] || ""
    end
    |> String.downcase()
  end

  defp ipv4(ips) do
    ips |> List.wrap() |> Enum.find(&String.contains?(&1, "."))
  end

  defp key_args do
    case config()[:ssh_key] || default_key() do
      nil -> []
      key -> ["-i", key, "-o", "IdentitiesOnly=yes"]
    end
  end

  defp default_key do
    path = Path.expand("~/.ssh/steamdeck_ed25519")
    if File.exists?(path), do: path
  end

  defp name_prefix, do: config()[:name_prefix] || "steamdeck"
  defp user, do: config()[:user] || "deck"
  defp config, do: Application.get_env(:japanese, __MODULE__, [])
end
