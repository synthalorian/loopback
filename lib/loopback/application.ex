defmodule Loopback.Application do
  @moduledoc """
  Loopback -- webhook testing tunnel with chaos mode.
  """
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # TODO: add workers
    ]

    opts = [strategy: :one_for_one, name: Loopback.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
