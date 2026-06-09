defmodule LoopbackWeb.TunnelDetailLiveTest do
  use LoopbackWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Loopback.Captures
  alias Loopback.Tunnels

  setup do
    on_exit(fn ->
      Loopback.Captures.ETS.clear()
      Loopback.Tunnels.Registry.clear()
    end)

    :ok
  end

  test "mounts and displays tunnel info", %{conn: conn} do
    {:ok, tunnel} = Tunnels.create_tunnel("http://localhost:3000")

    {:ok, _lv, html} = live(conn, "/tunnels/#{tunnel.id}")

    assert html =~ "Tunnel #{tunnel.id}"
    assert html =~ "http://localhost:3000"
  end

  test "shows not found for missing tunnel", %{conn: conn} do
    {:ok, _lv, html} = live(conn, "/tunnels/nonexistent")

    assert html =~ "Tunnel not found"
  end

  test "displays captured requests", %{conn: conn} do
    {:ok, tunnel} = Tunnels.create_tunnel("http://localhost:3000")

    conn_build = build_test_conn("POST", "/webhook", %{"foo" => "bar"})

    Captures.capture_request(conn_build, tunnel.id,
      response_status: 200,
      response_headers: [{"content-type", "application/json"}],
      response_body: ~s({"ok": true})
    )

    {:ok, _lv, html} = live(conn, "/tunnels/#{tunnel.id}")

    assert html =~ "POST"
    assert html =~ "/webhook"
    assert html =~ "200"
  end

  test "displays request details when selected", %{conn: conn} do
    {:ok, tunnel} = Tunnels.create_tunnel("http://localhost:3000")

    conn_build =
      build_test_conn("POST", "/webhook", %{"foo" => "bar"})
      |> Plug.Conn.put_req_header("content-type", "application/json")

    Captures.capture_request(conn_build, tunnel.id,
      response_status: 201,
      response_headers: [{"content-type", "application/json"}],
      response_body: ~s({"id": "123"})
    )

    {:ok, lv, _html} = live(conn, "/tunnels/#{tunnel.id}")

    [request] = Captures.list_requests(tunnel.id)

    html = element(lv, "button[phx-click='select_request']") |> render_click(%{"id" => request.id})

    assert html =~ "Request Detail"
    assert html =~ "POST"
    assert html =~ "/webhook"
    assert html =~ "201"
    assert html =~ ~s(&quot;id&quot;: &quot;123&quot;)
  end

  test "updates in real-time when new requests arrive", %{conn: conn} do
    {:ok, tunnel} = Tunnels.create_tunnel("http://localhost:3000")

    {:ok, lv, html} = live(conn, "/tunnels/#{tunnel.id}")

    assert html =~ "0 requests"

    conn_build = build_test_conn("GET", "/api/test")
    Captures.capture_request(conn_build, tunnel.id, response_status: 200)

    assert render(lv) =~ "GET"
    assert render(lv) =~ "/api/test"
  end

  test "shows empty state when no requests", %{conn: conn} do
    {:ok, tunnel} = Tunnels.create_tunnel("http://localhost:3000")

    {:ok, _lv, html} = live(conn, "/tunnels/#{tunnel.id}")

    assert html =~ "No requests captured yet"
  end

  defp build_test_conn(method, path, body \\ nil) do
    %Plug.Conn{
      method: method,
      path_info: String.split(path, "/", trim: true),
      query_string: "",
      req_headers: [{"accept", "application/json"}],
      assigns: if(body, do: %{raw_body: Jason.encode!(body)}, else: %{})
    }
  end
end
