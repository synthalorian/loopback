defmodule Loopback.CapturesTest do
  use ExUnit.Case, async: false

  alias Loopback.Captures
  alias Loopback.Captures.ETS

  setup do
    ETS.clear()
    :ok
  end

  describe "capture_request/3" do
    test "stores a request with response metadata" do
      conn = build_conn("POST", "/webhooks/github", %{"foo" => "bar"})

      request =
        Captures.capture_request(conn, "tunnel-1",
          response_status: 200,
          response_headers: [{"content-type", "application/json"}],
          response_body: ~s({"ok": true})
        )

      assert request.tunnel_id == "tunnel-1"
      assert request.method == "POST"
      assert request.path == "/webhooks/github"
      assert request.response_status == 200
      assert request.response_headers == [{"content-type", "application/json"}]
      assert request.response_body == ~s({"ok": true})
      assert %DateTime{} = request.inserted_at
    end

    test "generates a unique id for each request" do
      conn1 = build_conn("GET", "/a")
      conn2 = build_conn("GET", "/b")

      req1 = Captures.capture_request(conn1, "t1")
      req2 = Captures.capture_request(conn2, "t1")

      assert req1.id != req2.id
    end
  end

  describe "list_requests/1" do
    test "returns requests for a tunnel ordered newest first" do
      conn = build_conn("GET", "/")
      req1 = Captures.capture_request(conn, "tunnel-a")
      :timer.sleep(10)
      req2 = Captures.capture_request(conn, "tunnel-a")

      assert Captures.list_requests("tunnel-a") == [req2, req1]
    end

    test "returns an empty list when no requests exist" do
      assert Captures.list_requests("missing") == []
    end

    test "only returns requests for the specified tunnel" do
      conn = build_conn("GET", "/")
      Captures.capture_request(conn, "tunnel-a")
      Captures.capture_request(conn, "tunnel-b")

      assert length(Captures.list_requests("tunnel-a")) == 1
      assert length(Captures.list_requests("tunnel-b")) == 1
    end
  end

  describe "get_request/1" do
    test "returns the request when it exists" do
      conn = build_conn("GET", "/")
      request = Captures.capture_request(conn, "tunnel-1")

      assert Captures.get_request(request.id) == request
    end

    test "returns nil when the request does not exist" do
      assert Captures.get_request("nonexistent") == nil
    end
  end

  describe "delete_by_tunnel/1" do
    test "removes all requests for a tunnel" do
      conn = build_conn("GET", "/")
      request = Captures.capture_request(conn, "tunnel-1")

      assert :ok = Captures.delete_by_tunnel("tunnel-1")
      assert Captures.get_request(request.id) == nil
      assert Captures.list_requests("tunnel-1") == []
    end
  end

  describe "clear/0" do
    test "removes all stored requests" do
      conn = build_conn("GET", "/")
      Captures.capture_request(conn, "tunnel-1")
      Captures.capture_request(conn, "tunnel-2")

      assert :ok = Captures.clear()
      assert Captures.count() == 0
    end
  end

  describe "count/0" do
    test "returns the number of stored requests" do
      assert Captures.count() == 0

      conn = build_conn("GET", "/")
      Captures.capture_request(conn, "tunnel-1")
      assert Captures.count() == 1

      Captures.capture_request(conn, "tunnel-1")
      assert Captures.count() == 2
    end
  end

  describe "pruning" do
    test "old entries are dropped when max capacity is exceeded" do
      # Start a fresh ETS instance with a tiny capacity
      :ets.delete_all_objects(:loopback_captures)

      conn = build_conn("GET", "/")

      # Seed 5 requests
      for _ <- 1..5, do: Captures.capture_request(conn, "tunnel-1")

      # Verify all 5 are stored
      assert Captures.count() == 5
      assert length(Captures.list_requests("tunnel-1")) == 5

      # Now test pruning by creating a new ETS with capacity 3
      Supervisor.terminate_child(Loopback.Supervisor, Loopback.Captures.ETS)
      Supervisor.restart_child(Loopback.Supervisor, Loopback.Captures.ETS)

      # Seed 5 requests again - but this time the table has default capacity
      # We need a way to set capacity. Let's just verify the default behavior
      # by adding many requests.
      ETS.clear()

      for _i <- 1..10_005 do
        Captures.capture_request(conn, "tunnel-1")
      end

      # Should be capped at 10,000
      assert Captures.count() == 10_000
    end
  end

  defp build_conn(method, path, body \\ nil) do
    %Plug.Conn{
      method: method,
      path_info: String.split(path, "/", trim: true),
      query_string: "",
      req_headers: [{"accept", "application/json"}],
      assigns: if(body, do: %{raw_body: Jason.encode!(body)}, else: %{})
    }
  end
end
