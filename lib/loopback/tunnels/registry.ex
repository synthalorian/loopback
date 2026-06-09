defmodule Loopback.Tunnels.Registry do
  @moduledoc """
  In-memory registry for tunnels.
  """

  use GenServer

  alias Loopback.Tunnels.Tunnel

  @name __MODULE__

  # Client

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end

  def create(target_url) when is_binary(target_url) do
    GenServer.call(@name, {:create, target_url})
  end

  def get(id) when is_binary(id) do
    GenServer.call(@name, {:get, id})
  end

  def list do
    GenServer.call(@name, :list)
  end

  def delete(id) when is_binary(id) do
    GenServer.call(@name, {:delete, id})
  end

  def clear do
    GenServer.call(@name, :clear)
  end

  # Server

  @impl true
  def init(_opts) do
    {:ok, %{tunnels: %{}, next_id: 1}}
  end

  @impl true
  def handle_call({:create, target_url}, _from, state) do
    id = generate_id(state.next_id)

    tunnel = %Tunnel{
      id: id,
      target_url: target_url,
      inserted_at: DateTime.utc_now()
    }

    new_state = %{
      state
      | tunnels: Map.put(state.tunnels, id, tunnel),
        next_id: state.next_id + 1
    }

    {:reply, {:ok, tunnel}, new_state}
  end

  @impl true
  def handle_call({:get, id}, _from, state) do
    {:reply, Map.get(state.tunnels, id), state}
  end

  @impl true
  def handle_call(:list, _from, state) do
    tunnels =
      state.tunnels
      |> Map.values()
      |> Enum.sort_by(& &1.inserted_at, DateTime)

    {:reply, tunnels, state}
  end

  @impl true
  def handle_call({:delete, id}, _from, state) do
    new_tunnels = Map.delete(state.tunnels, id)
    {:reply, :ok, %{state | tunnels: new_tunnels}}
  end

  @impl true
  def handle_call(:clear, _from, state) do
    {:reply, :ok, %{state | tunnels: %{}, next_id: 1}}
  end

  defp generate_id(n) do
    n
    |> Integer.to_string(36)
    |> String.downcase()
    |> String.pad_leading(4, "0")
  end
end
