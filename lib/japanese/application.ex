defmodule Japanese.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  require Logger

  @impl Application
  def start(_type, _args) do
    children = [
      JapaneseWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:japanese, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Japanese.PubSub},
      {Finch,
       name: Japanese.Finch,
       pools: %{
         # Recycle idle HTTP/1 keep-alive connections well before Anthropic (or
         # any intermediary load balancer / NAT / firewall) silently drops an
         # idle socket. Finch's default conn_max_idle_time is :infinity, so a
         # dead connection lingers in the pool; the next request is written into
         # the half-open socket, never reaches the server (so it never appears in
         # Anthropic's logs), and fails only when receive_timeout expires as
         # %Req.TransportError{reason: :timeout}. 30s is safely under typical
         # server keep-alive windows (60-120s). This pool backs the Anthropic
         # client (see Japanese.Translation) as well as Hume/Fal/storage.
         default: [conn_max_idle_time: :timer.seconds(30)]
       }},
      {Task.Supervisor, name: Japanese.Task.Supervisor},
      {Japanese.Translation.Service.Server, name: Japanese.Translation.Service},
      # Game screenshots: the queue that OCRs/transcribes them, and the
      # watcher that finds them on a Steam Deck (a no-op when disabled).
      Japanese.Games.Processor,
      Japanese.Games.DeckWatcher,

      # Start to serve requests, typically the last entry
      JapaneseWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Japanese.Supervisor]
    result = Supervisor.start_link(children, opts)

    log_corpus_summary()

    result
  end

  # A single, cheap log line naming the corpus directory and how many story
  # directories are in it — a directory listing, not a scan of what is
  # inside those stories. Deliberately *not* a startup scan of every
  # translation file: with a couple hundred chapters that would delay boot,
  # it could not fix anything it found wrong (the corpus must never be
  # rewritten — see `Japanese.Corpus.Verify`), and a page that fails to
  # decode is already surfaced the moment someone opens it. This line exists
  # only so a misconfigured `CORPUS_DIR` (wrong path, empty mount) is visible
  # in the boot log instead of silently showing an empty story list.
  # `mix japanese.corpus.verify` is the tool for a deliberate, read-only
  # check of the actual content — run by the operator, not by every boot.
  @spec log_corpus_summary() :: :ok
  defp log_corpus_summary do
    Task.start(fn ->
      try do
        storage = Japanese.Corpus.StorageLayer.new()
        report_corpus(storage)
      rescue
        error -> Logger.warning("Corpus summary at boot failed: #{Exception.message(error)}")
      end
    end)

    :ok
  end

  @spec report_corpus(Japanese.Corpus.StorageLayer.t()) :: :ok
  defp report_corpus(storage) do
    case Japanese.Corpus.StorageLayer.list_stories(storage) do
      {:ok, stories} ->
        Logger.info("Corpus directory: #{storage.working_directory} (#{length(stories)} stories)")

      {:error, reason} ->
        Logger.warning(
          "Corpus directory #{storage.working_directory} could not be listed at boot: " <>
            inspect(reason)
        )
    end

    :ok
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl Application
  def config_change(changed, _new, removed) do
    JapaneseWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
