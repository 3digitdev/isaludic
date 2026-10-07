defmodule Isaludic.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      IsaludicWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:isaludic, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Isaludic.PubSub},
      # Start a worker by calling: Isaludic.Worker.start_link(arg)
      # {Isaludic.Worker, arg},
      # Start to serve requests, typically the last entry
      IsaludicWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Isaludic.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    IsaludicWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
