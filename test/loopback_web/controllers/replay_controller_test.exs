defmodule LoopbackWeb.ReplayControllerTest do
  use LoopbackWeb.ConnCase, async: false

  alias Loopback.Captures
  alias Loopback.Captures.ETS
  alias Loopback.Tunnels
  alias Loopback.Tunnels.Registry
  alias Loopback.TestTargetServer

  setup do
    Registry.clear()
    ETS.clear()
    {:ok, pid} = TestTargetServer.start()
    {:ok, target_url: TestTargetServer.url(pid), server: pid}
  end

  describe "POST /api/replays/:request_id" do
    test "exact replay without body", %{conn: conn, target_url: target_url} do
      {:ok, tunnel} = Tunnels.create_tunnel(target_url)

      # Create a captured request
      conn_capture = build_test_conn("GET", "/api/events")
      request = Captures.capture_request(conn_capture, tunnel.id, response_status: 200)

      conn = post(conn, "/api/replays/#{request.id}")

      assert json_response(conn, 200)
      response = json_response(conn, 200)
      assert response["method"] == "GET"
      assert response["path"] == "/api/events"
      assert response["response_status"] == 200
      assert response["id"] != request.id
    end

    test "modified replay with body", %{conn: conn, target_url: target_url} do
      {:ok, tunnel} = Tunnels.create_tunnel(target_url)

      conn_capture = build_test_conn("GET", "/api/events")
      request = Captures.capture_request(conn_capture, tunnel.id, response_status: 200)

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/replays/#{request.id}", %{
          "method" => "POST",
          "path" => "/webhooks/github",
          "query_string" => "foo=bar",
          "body" => ~s({"event": "push"})
        })

      assert json_response(conn, 200)
      response = json_response(conn, 200)
      assert response["method"] == "POST"
      assert response["path"] == "/webhooks/github"
      assert response["query_string"] == "foo=bar"
      assert response["body"] == ~s({"event": "push"})
      assert response["response_status"] == 200
    end

    test "returns 404 when request does not exist", %{conn: conn} do
      conn = post(conn, "/api/replays/nonexistent")
      assert json_response(conn, 404) == %{"error" => "request not found"}
    end

    test "modified replay with headers", %{conn: conn, target_url: target_url} do
      {:ok, tunnel} = Tunnels.create_tunnel(target_url)

      conn_capture = build_test_conn("GET", "/api/events")
      request = Captures.capture_request(conn_capture, tunnel.id, response_status: 200)

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/replays/#{request.id}", %{
          "headers" => %{
            "x-custom" => "custom-value",
            "accept" => "application/xml"
          }
        })

      assert json_response(conn, 200)
      response = json_response(conn, 200)
      headers = response["headers"]
      assert headers["x-custom"] == "custom-value"
      assert headers["accept"] == "application/xml"
    end
  end

  defp build_test_conn(method, path, body \\ nil) do
    %Plug.Conn{
      method: method,
      path_info: String.split(path, "/", trim: true),
      query_string: "",
      req_headers: [{"accept", "application/json"}],
      assigns: if(body, do: %{raw_body: Jason.encode!(body)}, else: %{})}
  end
end
