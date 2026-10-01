defmodule Japanese.Games.Processor do
  @moduledoc """
  Queue that turns found screenshots into finished `Japanese.Games.Shot`s,
  one at a time.

  When a screenshot is enqueued its record is saved straight away as
  `:pending` and broadcast as `{:shot_added, shot}`, so the UI can jump to it
  while it is still being worked on. The work itself (fetch the image into
  memory, `Japanese.Games.Pipeline.run/3`, save) happens in a supervised,
  unlinked task, so a crash or a hung HTTP call marks that one shot as
  failed instead of taking the queue down.

  Screenshots are human-paced, so one job at a time is plenty and keeps the
  Vision / Anthropic usage easy to reason about.
  """

  use GenServer

  require Logger

  alias Japanese.Games
  alias Japanese.Games.{Deck, Pipeline, Shot}

  # Vision (60s) + Claude (180s receive timeout) + fetch, with room to spare.
  @job_timeout :timer.minutes(6)

  @screenshot_path ~r{/(\d+)/screenshots/([^/]+\.(?:jpg|jpeg|png))$}i

  @type source :: {:deck, Deck.t()} | {:file, String.t()}

  # --- API ---

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  end

  @doc """
  Queues a screenshot found on a Deck at `remote_path`
  (`.../userdata/<user>/760/remote/<appid>/screenshots/<file>.jpg`). Paths
  that aren't screenshots (thumbnails, other files) and shots that already
  have a record are ignored.
  """
  @spec enqueue_deck(Deck.t(), String.t()) :: :ok | :ignored
  def enqueue_deck(%Deck{} = deck, remote_path) do
    case parse_remote_path(remote_path) do
      {:ok, appid, file} ->
        shot = Shot.new(deck.name, appid, file, source_path: remote_path)
        GenServer.call(__MODULE__, {:enqueue, shot, {:deck, deck}})

      :error ->
        :ignored
    end
  end

  @doc """
  Queues a local image file, recorded as coming from `deck` (default
  `"local"`). For trying the pipeline without a Deck:

      Japanese.Games.Processor.import_file("shot.jpg", "1718570")
  """
  @spec import_file(String.t(), String.t(), keyword()) :: :ok | :ignored
  def import_file(path, appid, opts \\ []) do
    deck = Keyword.get(opts, :deck, "local")
    shot = Shot.new(deck, appid, Path.basename(path), source_path: Path.expand(path))
    shot = %Shot{shot | game: Keyword.get(opts, :game)}
    GenServer.call(__MODULE__, {:enqueue, shot, {:file, Path.expand(path)}})
  end

  @doc """
  Re-runs a shot (e.g. after an error). The image is fetched again from where
  it came from: the Deck must be online, or the local file must still exist.
  """
  @spec retry(String.t()) :: :ok | {:error, term()}
  def retry(id) do
    with {:ok, shot} <- Games.get_shot(id),
         {:ok, source} <- source_for(shot) do
      GenServer.call(__MODULE__, {:retry, shot, source})
    end
  end

  @doc """
  Splits a Deck screenshot path into `{:ok, appid, file}`. Thumbnails don't
  match (their parent directory is `thumbnails`, not `screenshots`).
  """
  @spec parse_remote_path(String.t()) :: {:ok, String.t(), String.t()} | :error
  def parse_remote_path(path) do
    case Regex.run(@screenshot_path, path) do
      [_, appid, file] -> {:ok, appid, file}
      _ -> :error
    end
  end

  # --- GenServer ---

  @impl GenServer
  def init(_opts) do
    {:ok, %{queue: :queue.new(), queued: MapSet.new(), running: nil}}
  end

  @impl GenServer
  def handle_call({:enqueue, %Shot{id: id} = shot, source}, _from, state) do
    if MapSet.member?(state.queued, id) or Games.exists?(id) do
      {:reply, :ignored, state}
    else
      shot = %Shot{shot | game: shot.game || Games.known_game_name(shot.appid)}

      case Games.save_shot(shot) do
        {:ok, shot} ->
          Games.broadcast({:shot_added, shot})
          {:reply, :ok, state |> push(shot, source) |> run_next()}

        {:error, reason} ->
          Logger.warning("Could not save game shot #{id}: #{inspect(reason)}")
          {:reply, :ignored, state}
      end
    end
  end

  def handle_call({:retry, %Shot{id: id} = shot, source}, _from, state) do
    if MapSet.member?(state.queued, id) do
      {:reply, :ok, state}
    else
      shot = %Shot{shot | status: :pending, error: nil}
      {:ok, shot} = Games.save_shot(shot)
      Games.broadcast({:shot_updated, shot})
      {:reply, :ok, state |> push(shot, source) |> run_next()}
    end
  end

  @impl GenServer
  def handle_info({ref, result}, %{running: {ref, shot, _timer}} = state) do
    Process.demonitor(ref, [:flush])

    case result do
      {:ok, done} -> store(done)
      {:error, reason} -> fail(shot, reason)
    end

    {:noreply, finish_running(state)}
  end

  def handle_info({:DOWN, ref, :process, _pid, reason}, %{running: {ref, shot, _timer}} = state) do
    fail(shot, {:crashed, reason})
    {:noreply, finish_running(state)}
  end

  def handle_info({:job_timeout, ref}, %{running: {ref, shot, _timer}} = state) do
    Process.demonitor(ref, [:flush])
    fail(shot, :timeout)
    {:noreply, finish_running(state, kill: true)}
  end

  def handle_info(_message, state), do: {:noreply, state}

  # --- internals ---

  defp push(state, shot, source) do
    %{
      state
      | queue: :queue.in({shot, source}, state.queue),
        queued: MapSet.put(state.queued, shot.id)
    }
  end

  defp run_next(%{running: nil} = state) do
    case :queue.out(state.queue) do
      {{:value, {shot, source}}, queue} ->
        task =
          Task.Supervisor.async_nolink(Japanese.TaskSupervisor.name(), fn ->
            process(shot, source)
          end)

        timer = Process.send_after(self(), {:job_timeout, task.ref}, @job_timeout)
        %{state | queue: queue, running: {task.ref, shot, {timer, task.pid}}}

      {:empty, _} ->
        state
    end
  end

  defp run_next(state), do: state

  defp finish_running(%{running: {_ref, shot, {timer, pid}}} = state, opts \\ []) do
    Process.cancel_timer(timer)

    if Keyword.get(opts, :kill, false) do
      Task.Supervisor.terminate_child(Japanese.TaskSupervisor.name(), pid)
    end

    %{state | running: nil, queued: MapSet.delete(state.queued, shot.id)}
    |> run_next()
  end

  # Runs inside the task.
  defp process(%Shot{} = shot, source) do
    processing = %Shot{shot | status: :processing, game: shot.game || game_name(shot, source)}
    {:ok, processing} = Games.save_shot(processing)
    Games.broadcast({:shot_updated, processing})

    with {:ok, image} <- fetch(processing, source) do
      Pipeline.run(processing, image, media_type(processing.file))
    end
  end

  defp fetch(_shot, {:file, path}), do: File.read(path)
  defp fetch(shot, {:deck, deck}), do: Deck.fetch(deck, shot.source_path)

  defp game_name(shot, {:deck, deck}), do: Deck.game_name(deck, shot.appid)
  defp game_name(_shot, {:file, _}), do: nil

  defp store(shot) do
    case Games.save_shot(shot) do
      {:ok, shot} ->
        Games.broadcast({:shot_updated, shot})

      {:error, reason} ->
        Logger.warning("Could not save game shot #{shot.id}: #{inspect(reason)}")
    end
  end

  defp fail(%Shot{} = shot, reason) do
    Logger.warning("Game shot #{shot.id} failed: #{inspect(reason)}")

    # Keep whatever the record has now (e.g. the game name found while
    # processing), not the copy taken when the job was queued.
    current =
      case Games.get_shot(shot.id) do
        {:ok, %Shot{} = current} -> current
        _ -> shot
      end

    store(%Shot{current | status: :error, error: describe_error(reason)})
  end

  defp source_for(%Shot{deck: "local", source_path: path}) when is_binary(path) do
    if File.exists?(path), do: {:ok, {:file, path}}, else: {:error, :image_gone}
  end

  defp source_for(%Shot{deck: name}) do
    case Deck.find() do
      {:ok, %Deck{name: ^name} = deck} -> {:ok, {:deck, deck}}
      {:ok, _other} -> {:error, :deck_offline}
      {:error, _} -> {:error, :deck_offline}
    end
  end

  defp media_type(file) do
    case file |> Path.extname() |> String.downcase() do
      ".png" -> "image/png"
      _ -> "image/jpeg"
    end
  end

  @doc false
  @spec describe_error(term()) :: String.t()
  def describe_error(:missing_vision_api_key), do: "GOOGLE_VISION_API_KEY is not set"
  def describe_error(:timeout), do: "timed out"
  def describe_error(:truncated), do: "the model's reply was cut off"
  def describe_error(:invalid_transcript), do: "the model's reply was not valid JSON"
  def describe_error({:vision, message}), do: "Vision: #{message}"
  def describe_error({:vision_http, status, message}), do: "Vision HTTP #{status}: #{message}"
  def describe_error({:ssh_exit, code, _}), do: "could not copy from the Deck (ssh exit #{code})"
  def describe_error(:enoent), do: "image file not found"
  def describe_error(reason), do: inspect(reason, limit: 10)
end
