defmodule Japanese.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl Application
  def start(_type, _args) do
    children = [
      JapaneseWeb.Telemetry,
      # Japanese.Repo,
      {DNSCluster, query: Application.get_env(:japanese, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Japanese.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: Japanese.Finch},
      {Task.Supervisor, name: Japanese.Task.Supervisor},
      {Japanese.Translation.Service.Server, name: Japanese.Translation.Service},

      # Start to serve requests, typically the last entry
      JapaneseWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Japanese.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl Application
  def config_change(changed, _new, removed) do
    JapaneseWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
