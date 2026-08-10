defmodule Japanese.Translation.Service do
  @moduledoc """
  Asynchronously translates pages and tracks translation status.

  ## Status Tracking

  The service tracks the status of translations:
  - `:in_progress` - translation is currently running
  - `{:error, reason}` - translation failed with the given reason. Beyond the
    reasons the translation itself returns, the server supplies `:timeout` when
    a task blew past `timeout_ms/0` and was killed, and `:crashed` when the task
    process died without returning. All error states are retryable (the UI's
    Retry button clears them via `clear_error/1`).
  - `nil` - no status (check file existence for completed translations)

  Subscribe to page events to receive notifications:
  - `{:translation_started, %{story: story, page: page}}`
  - `{:translation_finished, %{story: story, page: page}}`
  - `{:translation_failed, %{story: story, page: page, reason: reason}}`
  """

  alias Japanese.Corpus.Page

  @type status :: :in_progress | {:error, term()} | nil
  @type page_key :: {String.t(), integer()}

  @doc """
  Asynchronously translates a page.

  Subscribe to page events to know when translation finishes or fails.
  """
  @spec translate_page(Page.t()) :: :ok
  def translate_page(%Page{} = page) do
    GenServer.cast(__MODULE__, {:translate_page, page})
  end

  @doc """
  Gets the current translation status for a page.

  Returns:
  - `:in_progress` - translation is running
  - `{:error, reason}` - translation failed
  - `nil` - no active status (check `page.translated?` for completion)
  """
  @spec get_status(Page.t()) :: status()
  def get_status(%Page{story: story, number: number}) do
    GenServer.call(__MODULE__, {:get_status, {story, number}})
  end

  @doc """
  Clears the error status for a page, allowing retry.
  """
  @spec clear_error(Page.t()) :: :ok
  def clear_error(%Page{story: story, number: number}) do
    GenServer.cast(__MODULE__, {:clear_error, {story, number}})
  end

  @doc """
  Lists all pages with active statuses (in_progress or error).
  """
  @spec list_statuses() :: %{page_key() => status()}
  def list_statuses do
    GenServer.call(__MODULE__, :list_statuses)
  end

  defmodule Server do
    @moduledoc false
    require Logger

    use GenServer
    alias Japanese.Corpus.Page

    def start_link(opts \\ []) do
      GenServer.start_link(__MODULE__, %{}, opts)
    end

    # `statuses` maps a page key to its user-visible status. `tasks` maps a
    # running task's monitor ref to everything the server needs to attribute an
    # outcome to it — the page key, the page, the task pid (to kill it on
    # timeout) and the pending timeout timer (to cancel when it finishes). The
    # ref→page mapping is the whole point: without it a crash or timeout has no
    # way to know *which* page just died, which is why the old crash handler
    # could only log and leave the status pinned at :in_progress forever.
    @impl GenServer
    def init(_init_arg) do
      {:ok, %{statuses: %{}, tasks: %{}}}
    end

    @impl GenServer
    def handle_cast({:translate_page, %Page{} = page}, state) do
      key = {page.story, page.number}

      # Don't start if already in progress
      case Map.get(state.statuses, key) do
        :in_progress ->
          Logger.warning("Translation already in progress for #{page.story} page #{page.number}")
          {:noreply, state}

        _ ->
          Japanese.Events.Page.translation_started(page)

          task =
            Task.Supervisor.async_nolink(Japanese.TaskSupervisor.name(), fn ->
              Logger.info("Translating story #{page.story} page #{page.number}")
              {key, page, Japanese.Translation.translate_page(page)}
            end)

          # Arm a hard ceiling so a wedged task can't pin the status forever.
          timer =
            Process.send_after(
              self(),
              {:translation_timeout, task.ref},
              Japanese.Translation.Service.timeout_ms()
            )

          state =
            state
            |> put_in([:statuses, key], :in_progress)
            |> put_in([:tasks, task.ref], %{
              key: key,
              page: page,
              pid: task.pid,
              timer: timer
            })

          {:noreply, state}
      end
    end

    def handle_cast({:clear_error, key}, state) do
      case Map.get(state.statuses, key) do
        {:error, _} ->
          {:noreply, %{state | statuses: Map.delete(state.statuses, key)}}

        _ ->
          {:noreply, state}
      end
    end

    @impl GenServer
    def handle_call({:get_status, key}, _from, state) do
      {:reply, Map.get(state.statuses, key), state}
    end

    def handle_call(:list_statuses, _from, state) do
      {:reply, state.statuses, state}
    end

    @impl GenServer
    # Task completed successfully.
    def handle_info({ref, {key, page, :ok}}, state) when is_reference(ref) do
      Process.demonitor(ref, [:flush])
      state = forget_task(state, ref)
      Logger.info("Finished translating story #{page.story} page #{page.number}")
      {:noreply, %{state | statuses: Map.delete(state.statuses, key)}}
    end

    # Task ran to completion but the translation itself returned an error.
    def handle_info({ref, {key, page, {:error, reason}}}, state) when is_reference(ref) do
      Process.demonitor(ref, [:flush])
      state = forget_task(state, ref)

      Logger.error(
        "Error translating story #{page.story} page #{page.number}: #{inspect(reason)}"
      )

      Japanese.Events.Page.translation_failed(page, reason)
      {:noreply, put_in(state.statuses[key], {:error, reason})}
    end

    # The hard ceiling fired before the task produced a result: it is wedged
    # (in practice, inside a stalled HTTP call). Kill it so its slot frees up,
    # record a retryable :timeout error and tell the UI — instead of leaving
    # the page pinned at :in_progress, which used to require an app restart. A
    # ref we no longer track means the task already finished and this is a
    # stale timer we couldn't cancel in time; there is nothing to do.
    def handle_info({:translation_timeout, ref}, state) do
      case Map.get(state.tasks, ref) do
        nil ->
          {:noreply, state}

        %{key: key, page: page, pid: pid} ->
          Logger.error(
            "Translation timed out for story #{page.story} page #{page.number} after " <>
              "#{Japanese.Translation.Service.timeout_ms()}ms; terminating task"
          )

          Task.Supervisor.terminate_child(Japanese.TaskSupervisor.name(), pid)
          Process.demonitor(ref, [:flush])
          state = forget_task(state, ref)
          Japanese.Events.Page.translation_failed(page, :timeout)
          {:noreply, put_in(state.statuses[key], {:error, :timeout})}
      end
    end

    # The task process died without sending a result: it crashed. Attribute the
    # crash to its page (that is what the ref→page map is for), record a
    # retryable :crashed error and notify the UI. The full reason goes to the
    # log, not the screen. A DOWN for a ref we no longer track was already
    # handled (its monitor was flushed) and is ignored.
    def handle_info({:DOWN, ref, :process, _pid, reason}, state) do
      case Map.get(state.tasks, ref) do
        nil ->
          {:noreply, state}

        %{key: key, page: page} ->
          state = forget_task(state, ref)

          Logger.error(
            "Translation task crashed for story #{page.story} page #{page.number}: " <>
              inspect(reason)
          )

          Japanese.Events.Page.translation_failed(page, :crashed)
          {:noreply, put_in(state.statuses[key], {:error, :crashed})}
      end
    end

    # A message the server was not built to handle. There was never a catch-all
    # that logged, so an unrecognised event used to vanish silently; this makes
    # the next unknown-message surprise visible in the log instead.
    def handle_info(msg, state) do
      Logger.warning("Translation.Service received an unexpected message: #{inspect(msg)}")
      {:noreply, state}
    end

    # Drop a finished/failed/killed task from the tracking map and cancel its
    # pending timeout timer so a leftover timer can't fire against a reused ref.
    @spec forget_task(map(), reference()) :: map()
    defp forget_task(state, ref) do
      case Map.pop(state.tasks, ref) do
        {nil, _tasks} ->
          state

        {%{timer: timer}, tasks} ->
          if timer, do: Process.cancel_timer(timer)
          %{state | tasks: tasks}
      end
    end
  end

  def config do
    Application.get_env(:japanese, __MODULE__, [])
  end

  @doc """
  The hard ceiling, in milliseconds, on a single async translation task.

  This is a backstop, not the primary timeout: a healthy translation finishes
  well inside it, and a stalled HTTP call is expected to fail on its own at
  `Japanese.Translation`'s (shorter) `receive_timeout` first. This only fires
  when a task is genuinely wedged, at which point the server kills it and marks
  the page `{:error, :timeout}`. It therefore sits deliberately *above* the
  HTTP receive timeout. Override with
  `config :japanese, Japanese.Translation.Service, timeout_ms: ms`.
  """
  @spec timeout_ms() :: pos_integer()
  def timeout_ms do
    config = config()

    case config[:timeout_ms] do
      nil -> 240 |> :timer.seconds()
      other -> other
    end
  end
end
