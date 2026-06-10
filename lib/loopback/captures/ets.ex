defmodule Loopback.Captures.ETS do
  @moduledoc """
  ETS-based request storage with configurable max capacity.

  Stores captured requests in a public ordered_set ETS table keyed by
  insertion time so the oldest entries can be pruned when the table
  reaches its configured limit.
  """

  use GenServer

  alias Loopback.Captures.Request

  @table :loopback_captures
  @max_entries 10_000
  @name __MODULE__

  # Client

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end

  @doc """
  Stores a request in ETS and prunes if over capacity.
  """
  @spec store(Request.t()) :: :ok
  def store(%Request{} = request) do
    GenServer.call(@name, {:store, request})
  end

  @doc """
  Returns the list of requests for a given tunnel, newest first.
  """
  @spec list_by_tunnel(String.t()) :: [Request.t()]
  def list_by_tunnel(tunnel_id) when is_binary(tunnel_id) do
    match = [{{{:_, tunnel_id}, :_, :"$1"}, [], [:"$1"]}]

    @table
    |> :ets.select(match)
    |> Enum.sort_by(& &1.inserted_at, DateTime)
    |> Enum.reverse()
  end

  @doc """
  Returns a single request by id.
  """
  @spec get(String.t()) :: Request.t() | nil
  def get(request_id) when is_binary(request_id) do
    match = [{{{request_id, :_}, :_, :"$1"}, [], [:"$1"]}]

    case :ets.select(@table, match, 1) do
      {[request], _continuation} -> request
      :"$end_of_table" -> nil
    end
  end

  @doc """
  Deletes all captured requests for a tunnel.
  """
  @spec delete_by_tunnel(String.t()) :: :ok
  def delete_by_tunnel(tunnel_id) when is_binary(tunnel_id) do
    GenServer.call(@name, {:delete_by_tunnel, tunnel_id})
  end

  @doc """
  Clears all stored requests.
  """
  @spec clear() :: :ok
  def clear do
    GenServer.call(@name, :clear)
  end

  @doc """
  Returns the total number of stored requests.
  """
  @spec count() :: non_neg_integer()
  def count do
    :ets.info(@table, :size)
  end

  # Server

  @impl true
  def init(opts) do
    max_entries = Keyword.get(opts, :max_entries, @max_entries)
    table = :ets.new(@table, [:set, :public, :named_table, read_concurrency: true])
    {:ok, %{table: table, max_entries: max_entries}}
  end

  @impl true
  def handle_call({:store, request}, _from, state) do
    key = {request.id, request.tunnel_id}
    true = :ets.insert(state.table, {key, request.tunnel_id, request})
    prune(state.table, state.max_entries)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:delete_by_tunnel, tunnel_id}, _from, state) do
    match = [{{{:_, tunnel_id}, :_, :_}, [], [true]}]
    :ets.select_delete(state.table, match)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:clear, _from, state) do
    :ets.delete_all_objects(state.table)
    {:reply, :ok, state}
  end

  defp prune(table, max_entries) do
    size = :ets.info(table, :size)

    if size > max_entries do
      to_delete = size - max_entries

      results = :ets.match(table, {:"$1", :_, :_}, to_delete)

      case results do
        {keys, _continuation} ->
          Enum.each(keys, fn [key] -> :ets.delete(table, key) end)

        :"$end_of_table" ->
          :ok
      end
    end
  end
end
