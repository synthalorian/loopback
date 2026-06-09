defmodule Loopback.PubSub do
  def child_spec(_opts) do
    Phoenix.PubSub.child_spec(name: __MODULE__)
  end
end
