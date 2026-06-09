defmodule Loopback.Replay do
  @moduledoc """
  Replay engine for captured requests.

  Supports exact replay (replay a captured request as-is) and modified replay
  (override method, path, query string, headers, or body before replaying).
  """

  alias Loopback.Captures
  alias Loopback.Captures.Request
  alias Loopback.Tunnels

  @hop_by_hop_headers [
    "connection",
    "keep-alive",
    "proxy-authenticate",
    "proxy-authorization",
    "te",
    "trailers",
    "transfer-encoding",
    "upgrade"
  ]

  @doc """
  Replays a captured request exactly as it was originally sent.

  Returns `{:ok, new_request}` on success or `{:error, reason}` on failure.
  """
  @spec replay_request(String.t()) :: {:ok, Request.t()} | {:error, term()}
  def replay_request(request_id) when is_binary(request_id) do
    with %Request{} = request <- Captures.get_request(request_id),
         %Tunnels.Tunnel{} = tunnel <- Tunnels.get_tunnel(request.tunnel_id) do
      execute_replay(tunnel, request, %{})
    else
      nil -> {:error, :not_found}
    end
  end

  @doc """
  Replays a captured request with modifications.

  `modifications` is a map with optional keys:
    * `:method` - override HTTP method (e.g. `"POST"`, `"GET"`)
    * `:path` - override request path (e.g. `"/api/events"`)
    * `:query_string` - override query string (e.g. `"foo=bar"`)
    * `:headers` - override request headers (list of `{name, value}` tuples)
    * `:body` - override request body (binary)

  Returns `{:ok, new_request}` on success or `{:error, reason}` on failure.
  """
  @spec replay_request(String.t(), map()) :: {:ok, Request.t()} | {:error, term()}
  def replay_request(request_id, %{} = modifications) when is_binary(request_id) do
    with %Request{} = request <- Captures.get_request(request_id),
         %Tunnels.Tunnel{} = tunnel <- Tunnels.get_tunnel(request.tunnel_id) do
      execute_replay(tunnel, request, modifications)
    else
      nil -> {:error, :not_found}
    end
  end

  defp execute_replay(tunnel, original_request, modifications) do
    method = Map.get(modifications, :method, original_request.method)
    path = Map.get(modifications, :path, original_request.path)
    query_string = Map.get(modifications, :query_string, original_request.query_string)
    headers = Map.get(modifications, :headers, original_request.headers)
    body = Map.get(modifications, :body, original_request.body)

    target_uri = build_target_uri(tunnel.target_url, path, query_string)
    url_charlist = target_uri |> URI.to_string() |> String.to_charlist()

    parsed_method = parse_method(method)
    req_body = body || ""
    req_headers = filter_headers(headers)

    result =
      if req_body == "" and parsed_method in [:get, :head, :delete, :options] do
        :httpc.request(parsed_method, {url_charlist, req_headers}, [], [body_format: :binary])
      else
        content_type = content_type_from_headers(headers)

        :httpc.request(
          parsed_method,
          {url_charlist, req_headers, content_type, req_body},
          [],
          [body_format: :binary]
        )
      end

    case result do
      {:ok, {{_http_version, status, _reason}, resp_headers, resp_body}} ->
        resp_headers = normalize_headers(resp_headers)

        request =
          build_replay_request(tunnel.id, method, path, query_string, headers, body,
            response_status: status,
            response_headers: resp_headers,
            response_body: resp_body
          )

        {:ok, request}

      {:error, _reason} ->
        request =
          build_replay_request(tunnel.id, method, path, query_string, headers, body,
            response_status: 502
          )

        {:ok, request}
    end
  end

  defp build_replay_request(tunnel_id, method, path, query_string, headers, body, opts) do
    id = generate_id()

    %Request{
      id: id,
      tunnel_id: tunnel_id,
      method: method,
      path: path,
      query_string: if(query_string in [nil, ""], do: nil, else: query_string),
      headers: headers || [],
      body: body,
      response_status: Keyword.get(opts, :response_status),
      response_headers: Keyword.get(opts, :response_headers),
      response_body: Keyword.get(opts, :response_body),
      inserted_at: DateTime.utc_now()
    }
    |> tap(&Captures.capture_replay_request/1)
  end

  defp generate_id do
    :crypto.strong_rand_bytes(8)
    |> Base.url_encode64(padding: false)
  end

  defp build_target_uri(target_url, path, query_string) do
    base = URI.parse(target_url)

    base
    |> URI.merge(path)
    |> Map.put(:query, if(query_string in [nil, ""], do: nil, else: query_string))
  end

  defp parse_method(method) do
    method
    |> to_string()
    |> String.downcase()
    |> String.to_atom()
  end

  defp filter_headers(headers) when is_list(headers) do
    headers
    |> Enum.reject(fn {name, _value} ->
      lower = String.downcase(name)
      lower in @hop_by_hop_headers or lower == "host"
    end)
    |> Enum.map(fn {name, value} ->
      {String.to_charlist(name), String.to_charlist(value)}
    end)
  end

  defp filter_headers(_), do: []

  defp content_type_from_headers(headers) when is_list(headers) do
    case List.keyfind(headers, "content-type", 0) do
      nil -> ~c"application/octet-stream"
      {_, value} -> String.to_charlist(value)
    end
  end

  defp content_type_from_headers(_), do: ~c"application/octet-stream"

  defp normalize_headers(headers) do
    headers
    |> Enum.reject(fn {name, _value} ->
      lower = List.to_string(name) |> String.downcase()
      lower in @hop_by_hop_headers
    end)
    |> Enum.map(fn {name, value} ->
      {List.to_string(name), List.to_string(value)}
    end)
  end
end
