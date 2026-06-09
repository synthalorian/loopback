defmodule LoopbackWeb.ReplayController do
  @moduledoc """
  API endpoints for replaying captured requests.
  """

  use LoopbackWeb, :controller

  alias Loopback.Replay

  @doc """
  Replays a captured request.

  POST /api/replays/:request_id

  Without a body, performs an exact replay. With a JSON body containing
  modifications, performs a modified replay.

  Modification keys:
    * "method" - HTTP method override
    * "path" - request path override
    * "query_string" - query string override
    * "headers" - headers override (object mapping header names to values)
    * "body" - request body override
  """
  def replay(conn, %{"request_id" => request_id}) do
    modifications = parse_modifications(conn.body_params)

    case Replay.replay_request(request_id, modifications) do
      {:ok, request} ->
        conn
        |> put_status(:ok)
        |> json(%{
          id: request.id,
          method: request.method,
          path: request.path,
          query_string: request.query_string,
          headers: request.headers |> Enum.into(%{}),
          body: request.body,
          response_status: request.response_status,
          response_headers: request.response_headers |> Enum.into(%{}),
          response_body: request.response_body,
          inserted_at: request.inserted_at |> DateTime.to_iso8601()
        })

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "request not found"})
    end
  end

  defp parse_modifications(%{} = params) when map_size(params) == 0, do: %{}

  defp parse_modifications(%{} = params) do
    %{
      method: Map.get(params, "method"),
      path: Map.get(params, "path"),
      query_string: Map.get(params, "query_string"),
      headers: parse_headers(Map.get(params, "headers")),
      body: Map.get(params, "body")
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  defp parse_headers(%{} = headers) do
    headers
    |> Enum.map(fn {name, value} -> {to_string(name), to_string(value)} end)
  end

  defp parse_headers(_), do: nil
end
