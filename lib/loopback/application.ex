defmodule Loopback.Application do
  @moduledoc """
  Loopback -- webhook testing tunnel with chaos mode.
  """
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      LoopbackWeb.Telemetry,
      Loopback.PubSub,
      Loopback.Tunnels.Registry,
      Loopback.Captures.ETS,
      Loopback.Transformations.Registry,
      Loopback.Chaos.Mode,
      LoopbackWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: Loopback.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    LoopbackWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
