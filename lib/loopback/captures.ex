defmodule Loopback.Captures do
  @moduledoc """
  Public API for capturing and retrieving tunnel requests.
  """

  alias Loopback.Captures.ETS
  alias Loopback.Captures.Request

  @doc """
  Captures a request and its response for a tunnel.

  Builds a `Request` struct from the conn and forwarded response, then
  stores it in ETS and broadcasts via PubSub.
  """
  @spec capture_request(Plug.Conn.t(), String.t(), keyword()) :: Request.t()
  def capture_request(conn, tunnel_id, opts \\ []) do
    request = build_request(conn, tunnel_id, opts)
    :ok = ETS.store(request)
    broadcast_request_captured(tunnel_id, request)
    request
  end

  @doc """
  Lists all captured requests for a tunnel, newest first.
  """
  @spec list_requests(String.t()) :: [Request.t()]
  def list_requests(tunnel_id) when is_binary(tunnel_id) do
    ETS.list_by_tunnel(tunnel_id)
  end

  @doc """
  Gets a single captured request by id.
  """
  @spec get_request(String.t()) :: Request.t() | nil
  def get_request(request_id) when is_binary(request_id) do
    ETS.get(request_id)
  end

  @doc """
  Deletes all captured requests for a tunnel.
  """
  @spec delete_by_tunnel(String.t()) :: :ok
  def delete_by_tunnel(tunnel_id) when is_binary(tunnel_id) do
    ETS.delete_by_tunnel(tunnel_id)
  end

  @doc """
  Clears all captured requests across all tunnels.
  """
  @spec clear() :: :ok
  def clear do
    ETS.clear()
  end

  @doc """
  Returns the total number of stored requests.
  """
  @spec count() :: non_neg_integer()
  def count do
    ETS.count()
  end

  @doc """
  Stores a replay request (already built by the replay engine) and broadcasts it.
  """
  @spec capture_replay_request(Request.t()) :: :ok
  def capture_replay_request(%Request{} = request) do
    :ok = ETS.store(request)
    broadcast_request_captured(request.tunnel_id, request)
    :ok
  end

  defp build_request(conn, tunnel_id, opts) do
    id = generate_id()

    path =
      Keyword.get_lazy(opts, :path, fn ->
        case conn.path_info do
          [] -> "/"
          segments -> "/" <> Path.join(segments)
        end
      end)

    %Request{
      id: id,
      tunnel_id: tunnel_id,
      method: conn.method,
      path: path,
      query_string: if(conn.query_string == "", do: nil, else: conn.query_string),
      headers: conn.req_headers,
      body: conn.assigns[:raw_body],
      response_status: Keyword.get(opts, :response_status),
      response_headers: Keyword.get(opts, :response_headers),
      response_body: Keyword.get(opts, :response_body),
      inserted_at: DateTime.utc_now()
    }
  end

  defp generate_id do
    :crypto.strong_rand_bytes(8)
    |> Base.url_encode64(padding: false)
  end

  defp broadcast_request_captured(tunnel_id, request) do
    Phoenix.PubSub.broadcast(
      Loopback.PubSub,
      "tunnel:#{tunnel_id}",
      {:request_captured, request}
    )
  end
end
