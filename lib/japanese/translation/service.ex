defmodule Japanese.Translation.Service do
  @moduledoc """
  Asynchronously translates pages and tracks translation status.

  ## Status Tracking

  The service tracks the status of translations:
  - `:in_progress` - translation is currently running
  - `{:error, reason}` - translation failed with the given reason
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
    alias Japanese.Translation.Service
    alias Japanese.Corpus.Page

    def start_link(opts \\ []) do
      GenServer.start_link(__MODULE__, %{}, opts)
    end

    @impl GenServer
    def init(_init_arg) do
      {:ok, %{statuses: %{}}}
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
          state = put_in(state.statuses[key], :in_progress)
          Japanese.Events.Page.translation_started(page)

          Task.Supervisor.async_nolink(Service.task_supervisor(), fn ->
            Logger.info("Translating story #{page.story} page #{page.number}")
            {key, page, Japanese.Translation.translate_page(page)}
          end)

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
    # Task completed successfully
    def handle_info({ref, {key, page, :ok}}, state) do
      Process.demonitor(ref, [:flush])
      Logger.info("Finished translating story #{page.story} page #{page.number}")
      {:noreply, %{state | statuses: Map.delete(state.statuses, key)}}
    end

    # Task completed with error
    def handle_info({ref, {key, page, {:error, reason}}}, state) do
      Process.demonitor(ref, [:flush])

      Logger.error(
        "Error translating story #{page.story} page #{page.number}: #{inspect(reason)}"
      )

      Japanese.Events.Page.translation_failed(page, reason)
      {:noreply, put_in(state.statuses[key], {:error, reason})}
    end

    # Task crashed
    def handle_info({:DOWN, _ref, :process, _pid, reason}, state) do
      Logger.error("Translation task crashed: #{inspect(reason)}")
      {:noreply, state}
    end

    def handle_info(_info, state) do
      {:noreply, state}
    end
  end

  def config do
    Application.get_env(:japanese, __MODULE__, [])
  end

  def timeout_ms do
    config = config()

    case config[:timeout_ms] do
      nil -> 600 |> :timer.seconds()
      other -> other
    end
  end

  def task_supervisor do
    config = config()

    case config[:task_supervisor] do
      nil -> Japanese.Task.Supervisor
      other -> other
    end
  end
end
