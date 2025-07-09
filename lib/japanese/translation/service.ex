defmodule Japanese.Translation.Service do

  @doc """
  Asynchronously translates a page. If you want to know when the translation is finished,
  you can subscribe to the `:translation_finished` event.
  """
  # Public API to cast a translation instruction for a Page
  def translate_page(%Japanese.Corpus.Page{} = page) do
    GenServer.cast(__MODULE__, {:translate_page, page})
  end

  defmodule Server do
    require Logger

    use GenServer
    alias Japanese.Translation.Service

    def start_link(opts \\ []) do
      GenServer.start_link(__MODULE__, nil, opts)
    end

   @impl GenServer
    def init(init_arg) do
      {:ok, init_arg}
    end

    @impl GenServer
    def handle_cast({:translate_page, %Japanese.Corpus.Page{} = page}, state) do
      timeout = Service.timeout_ms()

      Task.Supervisor.async(Service.task_supervisor(), fn ->
        Logger.info("Translating story #{page.story} page #{page.number}")

        case Japanese.Translation.translate_page(page) do
          :ok ->
            Logger.info("Finished translating story #{page.story} page #{page.number}")
          {:error, reason} ->
            Logger.error("Error translating story #{page.story} page #{page.number}: #{inspect(reason)} after #{timeout}ms")
        end
      end)
      |> Task.await(timeout)

      {:noreply, state}
    end

    @impl GenServer
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
        nil -> 120 |> :timer.seconds()
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
