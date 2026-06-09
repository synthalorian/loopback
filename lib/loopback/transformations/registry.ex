defmodule Loopback.Transformations.Registry do
  @moduledoc """
  In-memory registry mapping tunnel ids to their transformation scripts.
  """

  use GenServer

  @name __MODULE__

  # Client

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end

  def set(tunnel_id, script_text) when is_binary(tunnel_id) and is_binary(script_text) do
    GenServer.call(@name, {:set, tunnel_id, script_text})
  end

  def get(tunnel_id) when is_binary(tunnel_id) do
    GenServer.call(@name, {:get, tunnel_id})
  end

  def delete(tunnel_id) when is_binary(tunnel_id) do
    GenServer.call(@name, {:delete, tunnel_id})
  end

  def list do
    GenServer.call(@name, :list)
  end

  def clear do
    GenServer.call(@name, :clear)
  end

  # Server

  @impl true
  def init(_opts) do
    {:ok, %{scripts: %{}}}
  end

  @impl true
  def handle_call({:set, tunnel_id, script_text}, _from, state) do
    new_state = put_in(state.scripts[tunnel_id], script_text)
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:get, tunnel_id}, _from, state) do
    {:reply, Map.get(state.scripts, tunnel_id), state}
  end

  @impl true
  def handle_call({:delete, tunnel_id}, _from, state) do
    new_scripts = Map.delete(state.scripts, tunnel_id)
    {:reply, :ok, %{state | scripts: new_scripts}}
  end

  @impl true
  def handle_call(:list, _from, state) do
    {:reply, Map.to_list(state.scripts), state}
  end

  @impl true
  def handle_call(:clear, _from, _state) do
    {:reply, :ok, %{scripts: %{}}}
  end
end