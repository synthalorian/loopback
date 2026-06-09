defmodule LoopbackWeb.TransformationsControllerTest do
  use LoopbackWeb.ConnCase, async: false

  alias Loopback.Transformations.Registry
  alias Loopback.Tunnels
  alias Loopback.Tunnels.Registry, as: TunnelRegistry

  setup %{conn: conn} do
    TunnelRegistry.clear()
    Registry.clear()
    {:ok, tunnel} = Tunnels.create_tunnel("http://localhost:3000")
    {:ok, conn: conn, tunnel: tunnel}
  end

  describe "GET /api/tunnels/:tunnel_id/transformation" do
    test "returns 404 when no script exists", %{conn: conn, tunnel: tunnel} do
      conn = get(conn, "/api/tunnels/#{tunnel.id}/transformation")
      assert json_response(conn, 404) == %{"error" => "no transformation script found for this tunnel"}
    end

    test "returns the script when it exists", %{conn: conn, tunnel: tunnel} do
      script = "Map.put(ctx, :path, \"/modified\")"
      Loopback.Transformations.set_script(tunnel.id, script)

      conn = get(conn, "/api/tunnels/#{tunnel.id}/transformation")
      assert json_response(conn, 200) == %{"tunnel_id" => tunnel.id, "script" => script}
    end
  end

  describe "POST /api/tunnels/:tunnel_id/transformation" do
    test "creates a transformation script", %{conn: conn, tunnel: tunnel} do
      script = "Map.put(ctx, :path, \"/modified\")"

      conn = post(conn, "/api/tunnels/#{tunnel.id}/transformation", %{script: script})
      assert json_response(conn, 201) == %{"tunnel_id" => tunnel.id, "script" => script}
      assert Loopback.Transformations.get_script(tunnel.id) == script
    end

    test "returns 400 when script is missing", %{conn: conn, tunnel: tunnel} do
      conn = post(conn, "/api/tunnels/#{tunnel.id}/transformation", %{})
      assert json_response(conn, 400) == %{"error" => "missing required field: script"}
    end
  end

  describe "DELETE /api/tunnels/:tunnel_id/transformation" do
    test "deletes the transformation script", %{conn: conn, tunnel: tunnel} do
      Loopback.Transformations.set_script(tunnel.id, "ctx")

      conn = delete(conn, "/api/tunnels/#{tunnel.id}/transformation")
      assert response(conn, 204) == ""
      assert Loopback.Transformations.get_script(tunnel.id) == nil
    end
  end
end