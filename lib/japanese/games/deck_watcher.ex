defmodule Japanese.Games.DeckWatcher do
  @moduledoc """
  Watches a Steam Deck for new screenshots.

  While no Deck is reachable it checks `tailscale status` every
  `poll_interval` (default 15s). When a `steamdeck*` peer is online it opens
  one long-lived SSH session running a small shell script on the Deck
  (`remote_script/0`) that:

    1. starts `inotifywait` (a static binary in `~/.local/bin`) on Steam's
       screenshot folders, printing `NEW <path>` whenever a file is finished
       (`close_write`) or moved in,
    2. lists the screenshots already there as `EXISTING <path>`, then
       `READY`,
    3. blocks reading stdin, and kills `inotifywait` when stdin closes — so
       closing the port, or the connection dropping, never leaves a watcher
       running on the Deck.

  On `READY` it catches up: screenshots newer than the newest one already
  recorded for that Deck are queued; on the very first connection only the
  latest `initial_backfill` (default 3) are, not the Deck's whole history.

  When the Deck sleeps, SSH's keepalives end the session within ~30s and the
  watcher goes back to polling.

  Config (`config :japanese, Japanese.Games.DeckWatcher`): `:enabled`
  (default true; off in tests), `:poll_interval`, `:initial_backfill`.
  """

  use GenServer

  require Logger

  alias Japanese.Games
  alias Japanese.Games.{Deck, Processor, Shot}

  @type status :: :disabled | :searching | {:connected, String.t()}

  # --- API ---

  @spec start_link(keyword()) :: GenServer.on_start() | :ignore
  def start_link(opts) do
    if config(:enabled, true) do
      GenServer.start_link(__MODULE__, opts, name: __MODULE__)
    else
      :ignore
    end
  end

  @doc """
  Current status: `:searching` (no Deck connected) or `{:connected, name}`.
  """
  @spec status() :: status()
  def status, do: GenServer.call(__MODULE__, :status, 1_000)

  @doc """
  The shell script run on the Deck. It must not contain single quotes, and
  every line it prints is one of `NEW <path>`, `EXISTING <path>`, `READY`,
  `NODIR` or `NOWATCH`.
  """
  @spec remote_script() :: String.t()
  def remote_script do
    """
    R=$(ls -d "$HOME"/.local/share/Steam/userdata/*/760/remote 2>/dev/null)
    if [ -z "$R" ]; then echo NODIR; exit 3; fi
    W="$HOME/.local/bin/inotifywait"
    if [ ! -x "$W" ]; then echo NOWATCH; exit 4; fi
    "$W" -m -r -q -e close_write -e moved_to --format "NEW %w%f" $R &
    P=$!
    find $R -path "*/screenshots/*" ! -path "*/thumbnails/*" -type f -printf "EXISTING %p\\n"
    echo READY
    cat >/dev/null
    kill $P
    """
  end

  @doc """
  Which of the Deck's existing screenshots to queue when (re)connecting:
  those newer than the newest shot already recorded for that Deck, or — if
  there are none — just the latest `backfill`. Oldest first.
  """
  @spec catch_up([String.t()], [Shot.t()], String.t(), non_neg_integer()) :: [String.t()]
  def catch_up(paths, shots, deck_name, backfill) do
    candidates =
      paths
      |> Enum.flat_map(fn path ->
        case Processor.parse_remote_path(path) do
          {:ok, _appid, file} -> [{Path.rootname(file), path}]
          :error -> []
        end
      end)
      |> Enum.sort()

    newest_known =
      shots
      |> Enum.filter(&(&1.deck == deck_name))
      |> Enum.map(&Path.rootname(&1.file))
      |> Enum.max(fn -> nil end)

    case newest_known do
      nil -> Enum.take(candidates, -backfill)
      newest -> Enum.filter(candidates, fn {stamp, _} -> stamp > newest end)
    end
    |> Enum.map(&elem(&1, 1))
  end

  # --- GenServer ---

  @impl GenServer
  def init(_opts) do
    # So terminate/2 runs on shutdown and closes the SSH session cleanly.
    Process.flag(:trap_exit, true)
    send(self(), :poll)
    {:ok, %{deck: nil, port: nil, existing: [], reported: nil}}
  end

  @impl GenServer
  def handle_call(:status, _from, %{deck: %Deck{name: name}, port: port} = state)
      when is_port(port),
      do: {:reply, {:connected, name}, state}

  def handle_call(:status, _from, state), do: {:reply, :searching, state}

  @impl GenServer
  def handle_info(:poll, %{port: nil} = state) do
    case Deck.find() do
      {:ok, deck} ->
        {:noreply, connect(state, deck)}

      {:error, reason} ->
        {:noreply, state |> report(reason) |> schedule_poll()}
    end
  end

  def handle_info(:poll, state), do: {:noreply, state}

  def handle_info({port, {:data, {:eol, line}}}, %{port: port} = state) do
    {:noreply, handle_line(line, state)}
  end

  def handle_info({port, {:data, {:noeol, _partial}}}, %{port: port} = state) do
    {:noreply, state}
  end

  def handle_info({port, {:exit_status, code}}, %{port: port, deck: deck} = state) do
    Logger.info("Deck watcher: session with #{deck.name} ended (exit #{code})")
    Games.broadcast({:deck_status, :searching})

    {:noreply,
     %{state | port: nil, deck: nil, existing: [], reported: nil}
     |> schedule_poll(config(:poll_interval, 15_000))}
  end

  def handle_info(_message, state), do: {:noreply, state}

  @impl GenServer
  def terminate(_reason, %{port: port}) when is_port(port) do
    # Closing stdin makes the remote script kill inotifywait and exit.
    Port.close(port)
  catch
    _, _ -> :ok
  end

  def terminate(_reason, _state), do: :ok

  # --- internals ---

  defp connect(state, deck) do
    Logger.info("Deck watcher: connecting to #{deck.name} (#{deck.address})")

    port =
      Port.open({:spawn_executable, Deck.ssh()}, [
        :binary,
        :exit_status,
        :stderr_to_stdout,
        {:line, 8192},
        args: Deck.ssh_args(deck, remote_script())
      ])

    %{state | deck: deck, port: port, existing: [], reported: nil}
  end

  defp handle_line("NEW " <> path, state) do
    if Path.basename(Path.dirname(path)) == "screenshots" do
      Processor.enqueue_deck(state.deck, path)
    end

    state
  end

  defp handle_line("EXISTING " <> path, state), do: %{state | existing: [path | state.existing]}

  defp handle_line("READY", %{deck: deck} = state) do
    Logger.info("Deck watcher: watching #{deck.name} for screenshots")
    Games.broadcast({:deck_status, {:connected, deck.name}})

    state.existing
    |> catch_up(Games.list_shots(), deck.name, config(:initial_backfill, 3))
    |> Enum.each(&Processor.enqueue_deck(deck, &1))

    %{state | existing: []}
  end

  defp handle_line("NODIR", state) do
    Logger.info("Deck watcher: #{state.deck.name} has no screenshot folder yet")
    state
  end

  defp handle_line("NOWATCH", state) do
    Logger.warning(
      "Deck watcher: #{state.deck.name} has no ~/.local/bin/inotifywait; cannot watch"
    )

    state
  end

  defp handle_line(other, state) do
    Logger.info("Deck watcher (#{state.deck.name}): #{other}")
    state
  end

  # Only log a lookup failure when it changes, not every poll.
  defp report(%{reported: reason} = state, reason), do: state

  defp report(state, reason) do
    case reason do
      :no_deck -> Logger.info("Deck watcher: no Deck online; waiting")
      other -> Logger.warning("Deck watcher: cannot look for a Deck: #{inspect(other)}")
    end

    %{state | reported: reason}
  end

  defp schedule_poll(state, after_ms \\ nil) do
    Process.send_after(self(), :poll, after_ms || config(:poll_interval, 15_000))
    state
  end

  defp config(key, default) do
    Keyword.get(Application.get_env(:japanese, __MODULE__, []), key, default)
  end
end
