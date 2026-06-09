defmodule LoopbackWeb.TunnelListLiveTest do
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

  test "mounts and displays tunnels", %{conn: conn} do
    {:ok, tunnel} = Tunnels.create_tunnel("http://localhost:3000")

    {:ok, _lv, html} = live(conn, "/tunnels")

    assert html =~ "Tunnels"
    assert html =~ tunnel.id
    assert html =~ "http://localhost:3000"
  end

  test "shows empty state when no tunnels exist", %{conn: conn} do
    {:ok, _lv, html} = live(conn, "/tunnels")

    assert html =~ "No tunnels created yet"
  end

  test "displays request counts for each tunnel", %{conn: conn} do
    {:ok, tunnel} = Tunnels.create_tunnel("http://localhost:3000")

    conn_build = build_test_conn("POST", "/webhook", %{"foo" => "bar"})
    Captures.capture_request(conn_build, tunnel.id, response_status: 200)

    {:ok, _lv, html} = live(conn, "/tunnels")

    assert html =~ "1"
  end

  test "updates request count in real-time", %{conn: conn} do
    {:ok, tunnel} = Tunnels.create_tunnel("http://localhost:3000")

    {:ok, lv, _html} = live(conn, "/tunnels")

    conn_build = build_test_conn("POST", "/webhook", %{"foo" => "bar"})
    Captures.capture_request(conn_build, tunnel.id, response_status: 200)

    assert render(lv) =~ "1"
  end

  test "links to tunnel detail page", %{conn: conn} do
    {:ok, tunnel} = Tunnels.create_tunnel("http://localhost:3000")

    {:ok, _lv, html} = live(conn, "/tunnels")

    assert html =~ "href=\"/tunnels/#{tunnel.id}\""
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
