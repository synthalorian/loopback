defmodule LoopbackWeb.TunnelControllerTest do
  use LoopbackWeb.ConnCase, async: false

  alias Loopback.Captures
  alias Loopback.Captures.ETS
  alias Loopback.Tunnels
  alias Loopback.Tunnels.Registry
  alias Loopback.Transformations.Registry, as: TransformRegistry
  alias Loopback.TestTargetServer

  setup do
    Registry.clear()
    TransformRegistry.clear()
    ETS.clear()
    {:ok, pid} = TestTargetServer.start()
    {:ok, target_url: TestTargetServer.url(pid), server: pid}
  end

  describe "forward/2" do
    test "forwards a GET request preserving path and query string", %{conn: conn, target_url: target_url} do
      {:ok, tunnel} = Tunnels.create_tunnel(target_url)

      conn =
        conn
        |> get("/t/#{tunnel.id}/webhooks/github?foo=bar")

      assert response(conn, 200)
      echoed = Jason.decode!(response(conn, 200))
      assert echoed["method"] == "GET"
      assert echoed["path"] == "/webhooks/github"
      assert echoed["query_string"] == "foo=bar"
    end

    test "forwards a POST request preserving body", %{conn: conn, target_url: target_url} do
      {:ok, tunnel} = Tunnels.create_tunnel(target_url)

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/t/#{tunnel.id}/api/events", Jason.encode!(%{event: "push"}))

      assert response(conn, 200)
      echoed = Jason.decode!(response(conn, 200))
      assert echoed["method"] == "POST"
      assert echoed["path"] == "/api/events"
      assert echoed["body"] == %{"event" => "push"} |> Jason.encode!()
    end

    test "returns 404 when tunnel does not exist", %{conn: conn} do
      conn = get(conn, "/t/unknown/path")

      assert json_response(conn, 404) == %{"error" => "tunnel not found"}
    end

    test "captures a successful forwarded request", %{conn: conn, target_url: target_url} do
      {:ok, tunnel} = Tunnels.create_tunnel(target_url)

      conn
      |> put_req_header("content-type", "application/json")
      |> post("/t/#{tunnel.id}/api/events", Jason.encode!(%{event: "push"}))

      [request] = Captures.list_requests(tunnel.id)
      assert request.method == "POST"
      assert request.path == "/api/events"
      assert request.response_status == 200
      assert is_binary(request.response_body)
    end

    test "captures a failed forwarded request", %{conn: conn} do
      {:ok, tunnel} = Tunnels.create_tunnel("http://localhost:59999")

      conn = get(conn, "/t/#{tunnel.id}/fail")

      assert json_response(conn, 502)
      [request] = Captures.list_requests(tunnel.id)
      assert request.method == "GET"
      assert request.path == "/fail"
      assert request.response_status == 502
    end
  end
end
