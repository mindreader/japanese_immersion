defmodule Japanese.Translation.Service do

  # Public API to cast a translation instruction for a Page
  def translate_page(%Japanese.Corpus.Page{} = page) do
    GenServer.cast(__MODULE__, {:translate_page, page})
  end

  defmodule Server do
    require Logger

    use GenServer

    def start_link(opts \\ []) do
      GenServer.start_link(__MODULE__, nil, opts)
    end

    defp config do
      Application.get_env(:japanese, Japanese.Translation.Service, [])
    end

    @impl GenServer
    def init(init_arg) do
      {:ok, init_arg}
    end

    @impl GenServer
    def handle_cast({:translate_page, %Japanese.Corpus.Page{} = page}, state) do
      sup =
        case config()[:task_supervisor] do
          nil -> Japanese.Task.Supervisor
          other -> other
        end

      Task.Supervisor.start_child(sup, fn ->
        Logger.info("Translating story #{page.story} page #{page.number}")

        case Japanese.Corpus.Page.translate_page(page) do
          :ok ->
            Logger.info("Finished translating story #{page.story} page #{page.number}")

          {:error, reason} ->
            Logger.error("Error translating story #{page.story} page #{page.number}: #{inspect(reason)}")
        end
      end)
      {:noreply, state}
    end

    @impl GenServer
    def handle_info(_info, state) do
      {:noreply, state}
    end
  end
end
