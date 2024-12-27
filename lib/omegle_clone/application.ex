defmodule OmegleClone.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      OmegleCloneWeb.Telemetry,
      OmegleClone.Repo,
      {DNSCluster, query: Application.get_env(:omegle_clone, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: OmegleClone.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: OmegleClone.Finch},
      # Start a worker by calling: OmegleClone.Worker.start_link(arg)
      # {OmegleClone.Worker, arg},
      # Start to serve requests, typically the last entry
      OmegleCloneWeb.Endpoint,
      OmegleCloneWeb.Presence,
      OmegleClone.PeerSupervisor,
      OmegleClone.RoomSupervisor,
      OmegleClone.RoomRegistryServer,
      {Registry, name: OmegleClone.PeerRegistry, keys: :unique},
      {Registry, name: OmegleClone.RoomRegistry, keys: :unique},
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: OmegleClone.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    OmegleCloneWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
