defmodule Loopback.TunnelsTest do
  use ExUnit.Case, async: false

  alias Loopback.Tunnels
  alias Loopback.Tunnels.Registry

  setup do
    Registry.clear()
    :ok
  end

  describe "create_tunnel/1" do
    test "creates a tunnel with an auto-generated id" do
      assert {:ok, tunnel} = Tunnels.create_tunnel("http://localhost:3000")
      assert tunnel.target_url == "http://localhost:3000"
      assert is_binary(tunnel.id)
      assert %DateTime{} = tunnel.inserted_at
    end
  end

  describe "get_tunnel/1" do
    test "returns the tunnel when it exists" do
      {:ok, tunnel} = Tunnels.create_tunnel("http://localhost:3000")
      assert Tunnels.get_tunnel(tunnel.id) == tunnel
    end

    test "returns nil when the tunnel does not exist" do
      assert Tunnels.get_tunnel("missing") == nil
    end
  end

  describe "list_tunnels/0" do
    test "returns tunnels ordered by insertion time" do
      {:ok, first} = Tunnels.create_tunnel("http://localhost:3001")
      {:ok, second} = Tunnels.create_tunnel("http://localhost:3002")

      assert Tunnels.list_tunnels() == [first, second]
    end

    test "returns an empty list when there are no tunnels" do
      assert Tunnels.list_tunnels() == []
    end
  end

  describe "delete_tunnel/1" do
    test "removes the tunnel" do
      {:ok, tunnel} = Tunnels.create_tunnel("http://localhost:3000")
      assert :ok = Tunnels.delete_tunnel(tunnel.id)
      assert Tunnels.get_tunnel(tunnel.id) == nil
    end
  end
end
