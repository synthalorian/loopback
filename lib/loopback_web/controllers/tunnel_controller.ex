defmodule LoopbackWeb.TunnelController do
  @moduledoc """
  Forwards incoming tunnel requests to the configured local target.
  """

  use LoopbackWeb, :controller

  alias Loopback.Captures
  alias Loopback.Chaos
  alias Loopback.Transformations
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

  def forward(conn, %{"tunnel_id" => tunnel_id, "path" => path}) do
    case Tunnels.get_tunnel(tunnel_id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "tunnel not found"})

      tunnel ->
        forward_to_target(conn, tunnel.id, tunnel.target_url, path)
    end
  end

  defp forward_to_target(conn, tunnel_id, target_url, path_segments) do
    path = "/" <> Path.join(path_segments)

    ctx = %{
      method: conn.method,
      path: path,
      query_string: if(conn.query_string == "", do: nil, else: conn.query_string),
      headers: conn.req_headers,
      body: conn.assigns[:raw_body]
    }

    ctx =
      case Transformations.transform(tunnel_id, ctx) do
        {:ok, transformed} -> transformed
        {:error, _reason} -> ctx
      end

    body = ctx.body || ""

    case Chaos.apply_chaos(body) do
      {:error, :chaos_drop} ->
        _request =
          Captures.capture_request(conn, tunnel_id,
            response_status: 503,
            path: "/" <> Path.join(path_segments)
          )

        conn
        |> put_status(:service_unavailable)
        |> json(%{error: "chaos mode: request dropped"})
        |> halt()

      {:ok, chaos_body} ->
        target_uri = build_target_uri(target_url, ctx.path, ctx.query_string)
        url_charlist = target_uri |> URI.to_string() |> String.to_charlist()

        method = parse_method(ctx.method)
        req_headers = filter_headers(ctx.headers)

        result =
          if chaos_body == "" and method in [:get, :head, :delete, :options] do
            :httpc.request(method, {url_charlist, req_headers}, [], [body_format: :binary])
          else
            content_type = content_type_from_headers(conn.req_headers)

            :httpc.request(
              method,
              {url_charlist, req_headers, content_type, chaos_body},
              [],
              [body_format: :binary]
            )
          end

        case result do
          {:ok, {{_http_version, status, _reason}, resp_headers, resp_body}} ->
            resp_headers = normalize_headers(resp_headers)

            _request =
              Captures.capture_request(conn, tunnel_id,
                response_status: status,
                response_headers: resp_headers,
                response_body: resp_body,
                path: "/" <> Path.join(path_segments)
              )

            conn
            |> put_status(status)
            |> put_resp_headers(resp_headers)
            |> send_resp(status, resp_body)
            |> halt()

          {:error, reason} ->
            _request =
              Captures.capture_request(conn, tunnel_id,
                response_status: 502,
                path: "/" <> Path.join(path_segments)
              )

            conn
            |> put_status(:bad_gateway)
            |> json(%{error: "failed to forward request", reason: inspect(reason)})
        end
    end
  end

  defp build_target_uri(target_url, path, query_string) when is_binary(path) do
    base = URI.parse(target_url)

    base
    |> URI.merge(path)
    |> Map.put(:query, if(query_string in [nil, ""], do: nil, else: query_string))
  end

  defp parse_method(method) do
    method
    |> String.downcase()
    |> String.to_atom()
  end

  defp filter_headers(headers) do
    headers
    |> Enum.reject(fn {name, _value} ->
      lower = String.downcase(name)
      lower in @hop_by_hop_headers or lower == "host"
    end)
    |> Enum.map(fn {name, value} ->
      {String.to_charlist(name), String.to_charlist(value)}
    end)
  end

  defp content_type_from_headers(headers) do
    case List.keyfind(headers, "content-type", 0) do
      nil -> ~c"application/octet-stream"
      {_, value} -> String.to_charlist(value)
    end
  end

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

  defp put_resp_headers(conn, headers) do
    Enum.reduce(headers, conn, fn {key, value}, acc ->
      put_resp_header(acc, key, value)
    end)
  end
end
