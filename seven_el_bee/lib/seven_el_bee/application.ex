defmodule SevenElBee.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      SevenElBeeWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:seven_el_bee, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: SevenElBee.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: SevenElBee.Finch},
      # Start a worker by calling: SevenElBee.Worker.start_link(arg)
      # {SevenElBee.Worker, arg},
      # Start to serve requests, typically the last entry
      SevenElBeeWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: SevenElBee.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    SevenElBeeWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
