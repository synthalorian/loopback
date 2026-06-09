defmodule Loopback.ReplayTest do
  use ExUnit.Case, async: false

  alias Loopback.Captures
  alias Loopback.Captures.ETS
  alias Loopback.Replay
  alias Loopback.Tunnels
  alias Loopback.Tunnels.Registry
  alias Loopback.TestTargetServer

  setup do
    Registry.clear()
    ETS.clear()
    {:ok, pid} = TestTargetServer.start()
    {:ok, target_url: TestTargetServer.url(pid), server: pid}
  end

  describe "replay_request/1 (exact replay)" do
    test "replays a captured request exactly", %{target_url: target_url} do
      {:ok, tunnel} = Tunnels.create_tunnel(target_url)

      # Simulate a captured POST request
      conn = build_conn("POST", "/api/events", %{"event" => "push"})
      request = Captures.capture_request(conn, tunnel.id, response_status: 200, response_body: ~s({"ok": true}))

      # Replay it
      assert {:ok, replayed} = Replay.replay_request(request.id)
      assert replayed.tunnel_id == tunnel.id
      assert replayed.method == "POST"
      assert replayed.path == "/api/events"
      assert replayed.response_status == 200
      assert replayed.body == Jason.encode!(%{"event" => "push"})
    end

    test "returns error when request does not exist" do
      assert {:error, :not_found} = Replay.replay_request("nonexistent")
    end

    test "returns error when tunnel does not exist" do
      conn = build_conn("GET", "/")
      # Manually create a request without a valid tunnel
      request = Captures.capture_request(conn, "invalid-tunnel")

      assert {:error, :not_found} = Replay.replay_request(request.id)
    end
  end

  describe "replay_request/2 (modified replay)" do
    test "replays with modified method", %{target_url: target_url} do
      {:ok, tunnel} = Tunnels.create_tunnel(target_url)

      conn = build_conn("GET", "/api/events")
      request = Captures.capture_request(conn, tunnel.id, response_status: 200)

      assert {:ok, replayed} = Replay.replay_request(request.id, %{method: "POST", body: ~s({"test": true})})
      assert replayed.method == "POST"
      assert replayed.response_status == 200
    end

    test "replays with modified path", %{target_url: target_url} do
      {:ok, tunnel} = Tunnels.create_tunnel(target_url)

      conn = build_conn("GET", "/old-path")
      request = Captures.capture_request(conn, tunnel.id, response_status: 200)

      assert {:ok, replayed} = Replay.replay_request(request.id, %{path: "/webhooks/github"})
      assert replayed.path == "/webhooks/github"
      assert replayed.response_status == 200
    end

    test "replays with modified query string", %{target_url: target_url} do
      {:ok, tunnel} = Tunnels.create_tunnel(target_url)

      conn = build_conn("GET", "/api/events")
      request = Captures.capture_request(conn, tunnel.id, response_status: 200)

      assert {:ok, replayed} = Replay.replay_request(request.id, %{query_string: "foo=bar&baz=qux"})
      assert replayed.query_string == "foo=bar&baz=qux"
      assert replayed.response_status == 200
    end

    test "replays with modified headers", %{target_url: target_url} do
      {:ok, tunnel} = Tunnels.create_tunnel(target_url)

      conn = build_conn("GET", "/api/events", nil, [{"x-original", "value"}])
      request = Captures.capture_request(conn, tunnel.id, response_status: 200)

      assert {:ok, replayed} = Replay.replay_request(request.id, %{
        headers: [{"x-modified", "new-value"}, {"accept", "application/xml"}]
      })

      assert replayed.headers == [{"x-modified", "new-value"}, {"accept", "application/xml"}]
      assert replayed.response_status == 200
    end

    test "replays with modified body", %{target_url: target_url} do
      {:ok, tunnel} = Tunnels.create_tunnel(target_url)

      conn = build_conn("POST", "/api/events", %{"old" => "data"})
      request = Captures.capture_request(conn, tunnel.id, response_status: 200)

      assert {:ok, replayed} = Replay.replay_request(request.id, %{body: ~s({"new": "data"})})
      assert replayed.body == ~s({"new": "data"})
      assert replayed.response_status == 200
    end

    test "replays with multiple modifications", %{target_url: target_url} do
      {:ok, tunnel} = Tunnels.create_tunnel(target_url)

      conn = build_conn("GET", "/old", nil, [{"x-old", "old"}])
      request = Captures.capture_request(conn, tunnel.id, response_status: 200)

      assert {:ok, replayed} = Replay.replay_request(request.id, %{
        method: "POST",
        path: "/new",
        query_string: "new=param",
        headers: [{"x-new", "new"}],
        body: ~s({"new": true})
      })

      assert replayed.method == "POST"
      assert replayed.path == "/new"
      assert replayed.query_string == "new=param"
      assert replayed.headers == [{"x-new", "new"}]
      assert replayed.body == ~s({"new": true})
      assert replayed.response_status == 200
    end
  end

  describe "replay capture" do
    test "replayed requests are captured and stored", %{target_url: target_url} do
      {:ok, tunnel} = Tunnels.create_tunnel(target_url)

      conn = build_conn("GET", "/api/events")
      original = Captures.capture_request(conn, tunnel.id, response_status: 200)

      initial_count = Captures.count()
      assert {:ok, _replayed} = Replay.replay_request(original.id)
      assert Captures.count() == initial_count + 1

      # The replayed request should appear in the tunnel's request list
      requests = Captures.list_requests(tunnel.id)
      assert length(requests) == 2
    end
  end

  defp build_conn(method, path, body \\ nil, headers \\ [{"accept", "application/json"}]) do
    %Plug.Conn{
      method: method,
      path_info: String.split(path, "/", trim: true),
      query_string: "",
      req_headers: headers,
      assigns: if(body, do: %{raw_body: Jason.encode!(body)}, else: %{})}
  end
end
