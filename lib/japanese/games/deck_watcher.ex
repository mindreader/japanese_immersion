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

  Nothing taken more than `max_age_days` (default 7) ago is ever queued
  automatically, by catch-up or by a new-file event, so losing the stored
  shots (or a fresh install) can't turn into processing years of old
  screenshots. Age comes from Steam's file name (Deck local time), against
  this machine's local clock. A shot can still be imported by hand.

  When the Deck sleeps, SSH's keepalives end the session within ~30s and the
  watcher goes back to polling.

  Logging: `Steam Deck connected: <name> (<address>)` once the watch is up,
  and `Steam Deck disconnected: <name> after <duration>` when the session
  ends. A session that fails before it is up is a single warning per Deck
  (with ssh's own output), not one per retry.

  Config (`config :japanese, Japanese.Games.DeckWatcher`): `:enabled`
  (default true; off in tests), `:poll_interval`, `:initial_backfill`,
  `:max_age_days`.
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

  Only shots taken at or after `cutoff` (a `YYYYMMDDHHMMSS` stamp, see
  `cutoff/1`) are considered at all; a file whose name carries no
  timestamp can't be dated, so it is skipped too. `nil` means no cutoff.
  """
  @spec catch_up([String.t()], [Shot.t()], String.t(), non_neg_integer(), String.t() | nil) ::
          [String.t()]
  def catch_up(paths, shots, deck_name, backfill, cutoff \\ nil) do
    candidates =
      paths
      |> Enum.flat_map(fn path ->
        case Processor.parse_remote_path(path) do
          {:ok, _appid, file} -> [{Path.rootname(file), path}]
          :error -> []
        end
      end)
      |> Enum.filter(fn {stamp, _} -> cutoff == nil or recent?(stamp, cutoff) end)
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

  @doc """
  The `YYYYMMDDHHMMSS` stamp `max_age_days` before `now` (local time).
  """
  @spec cutoff(NaiveDateTime.t()) :: String.t()
  def cutoff(now \\ NaiveDateTime.local_now()) do
    now
    |> NaiveDateTime.add(-config(:max_age_days, 7) * 86_400, :second)
    |> Calendar.strftime("%Y%m%d%H%M%S")
  end

  @doc """
  Whether a screenshot file name (or its stem) was taken at or after
  `cutoff`. False when the name has no Steam timestamp.
  """
  @spec recent?(String.t(), String.t()) :: boolean()
  def recent?(name, cutoff) do
    case Regex.run(~r/^\d{14}/, Path.basename(name)) do
      [stamp] -> stamp >= cutoff
      nil -> false
    end
  end

  # --- GenServer ---

  @impl GenServer
  def init(_opts) do
    # So terminate/2 runs on shutdown and closes the SSH session cleanly.
    Process.flag(:trap_exit, true)

    case Deck.ssh_key() |> Deck.key_problem() do
      nil -> :ok
      problem -> Logger.warning("Deck watcher: SSH key problem: #{problem}")
    end

    send(self(), :poll)
    {:ok, initial_state()}
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

  def handle_info({port, {:exit_status, code}}, %{port: port} = state) do
    failed = log_session_end(state, code)
    Games.broadcast({:deck_status, :searching})

    {:noreply,
     %{initial_state() | failed: failed}
     |> schedule_poll(config(:poll_interval, 15_000))}
  end

  def handle_info(_message, state), do: {:noreply, state}

  @impl GenServer
  def terminate(_reason, %{port: port} = state) when is_port(port) do
    if state.connected_at do
      Logger.info("Steam Deck disconnected: #{state.deck.name} (shutting down)")
    end

    # Closing stdin makes the remote script kill inotifywait and exit.
    Port.close(port)
  catch
    _, _ -> :ok
  end

  def terminate(_reason, _state), do: :ok

  # --- internals ---

  defp initial_state do
    %{
      deck: nil,
      port: nil,
      existing: [],
      reported: nil,
      # System.monotonic_time(:second) when READY arrived; nil until then.
      connected_at: nil,
      # Output before READY (ssh errors, mostly), newest first, for the
      # warning if the session never gets that far.
      early_output: [],
      # Name of the Deck whose failed connection was already logged, so a
      # Deck that keeps failing every poll is one warning, not hundreds.
      failed: nil
    }
  end

  @doc false
  # Logs the end of an SSH session and returns the new `failed` marker.
  def log_session_end(%{deck: deck, connected_at: connected_at}, code)
      when is_integer(connected_at) do
    duration = System.monotonic_time(:second) - connected_at

    Logger.info(
      "Steam Deck disconnected: #{deck.name} after #{format_duration(duration)} (exit #{code})"
    )

    nil
  end

  def log_session_end(%{deck: deck, failed: failed} = state, code) do
    if failed == deck.name do
      Logger.debug("Deck watcher: #{deck.name} still not reachable (exit #{code})")
    else
      output =
        case state.early_output |> Enum.take(5) |> Enum.reverse() do
          [] -> ""
          lines -> ": " <> Enum.join(lines, " / ")
        end

      Logger.warning(
        "Deck watcher: could not connect to #{deck.name} (#{deck.address}), " <>
          "exit #{code}#{output}; will keep retrying"
      )
    end

    deck.name
  end

  @doc false
  def format_duration(seconds) when seconds < 60, do: "#{seconds}s"
  def format_duration(seconds) when seconds < 3600, do: "#{div(seconds, 60)}m"

  def format_duration(seconds),
    do: "#{div(seconds, 3600)}h #{seconds |> rem(3600) |> div(60)}m"

  defp connect(state, deck) do
    Logger.debug("Deck watcher: connecting to #{deck.name} (#{deck.address})")

    port =
      Port.open({:spawn_executable, Deck.ssh()}, [
        :binary,
        :exit_status,
        :stderr_to_stdout,
        {:line, 8192},
        args: Deck.ssh_args(deck, remote_script())
      ])

    %{state | deck: deck, port: port, existing: [], reported: nil, early_output: []}
  end

  defp handle_line("NEW " <> path, state) do
    cond do
      Path.basename(Path.dirname(path)) != "screenshots" ->
        :ok

      # A file can be "new" here and still old: moved in, restored, or
      # re-synced by Steam. One with no timestamp in its name was just
      # written, so it goes through.
      Regex.match?(~r/^\d{14}/, Path.basename(path)) and not recent?(path, cutoff()) ->
        Logger.info("Deck watcher: skipping #{Path.basename(path)}, older than #{max_age()} days")

      true ->
        Processor.enqueue_deck(state.deck, path)
    end

    state
  end

  defp handle_line("EXISTING " <> path, state), do: %{state | existing: [path | state.existing]}

  defp handle_line("READY", %{deck: deck} = state) do
    Logger.info("Steam Deck connected: #{deck.name} (#{deck.address})")
    Games.broadcast({:deck_status, {:connected, deck.name}})

    cutoff = cutoff()

    old =
      Enum.count(state.existing, fn path ->
        Processor.parse_remote_path(path) != :error and not recent?(path, cutoff)
      end)

    if old > 0 do
      Logger.info(
        "Deck watcher: ignoring #{old} screenshot(s) on #{deck.name} older than #{max_age()} days"
      )
    end

    state.existing
    |> catch_up(Games.list_shots(), deck.name, config(:initial_backfill, 3), cutoff)
    |> Enum.each(&Processor.enqueue_deck(deck, &1))

    %{
      state
      | existing: [],
        early_output: [],
        failed: nil,
        connected_at: System.monotonic_time(:second)
    }
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

  # Before READY, anything else is almost always ssh complaining; keep it for
  # the failure warning rather than logging it on every retry.
  defp handle_line(other, %{connected_at: nil} = state),
    do: %{state | early_output: [other | state.early_output]}

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

  defp max_age, do: config(:max_age_days, 7)

  defp config(key, default) do
    Keyword.get(Application.get_env(:japanese, __MODULE__, []), key, default)
  end
end
