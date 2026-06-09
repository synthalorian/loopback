defmodule Loopback.TransformationsTest do
  use ExUnit.Case, async: false

  alias Loopback.Transformations
  alias Loopback.Transformations.Registry

  setup do
    Registry.clear()
    :ok
  end

  describe "set_script/2 and get_script/1" do
    test "stores and retrieves a script" do
      assert :ok = Transformations.set_script("tunnel-1", "ctx")
      assert Transformations.get_script("tunnel-1") == "ctx"
    end

    test "overwrites an existing script" do
      assert :ok = Transformations.set_script("tunnel-1", "original")
      assert :ok = Transformations.set_script("tunnel-1", "updated")
      assert Transformations.get_script("tunnel-1") == "updated"
    end
  end

  describe "delete_script/1" do
    test "removes a script" do
      assert :ok = Transformations.set_script("tunnel-1", "ctx")
      assert :ok = Transformations.delete_script("tunnel-1")
      assert Transformations.get_script("tunnel-1") == nil
    end
  end

  describe "list_scripts/0" do
    test "returns all stored scripts" do
      assert :ok = Transformations.set_script("tunnel-1", "script1")
      assert :ok = Transformations.set_script("tunnel-2", "script2")

      scripts = Transformations.list_scripts()
      assert length(scripts) == 2
      assert {"tunnel-1", "script1"} in scripts
      assert {"tunnel-2", "script2"} in scripts
    end
  end

  describe "transform/2" do
    test "returns unchanged ctx when no script exists" do
      ctx = %{method: "GET", path: "/", query_string: nil, headers: [], body: nil}
      assert {:ok, ^ctx} = Transformations.transform("no-script", ctx)
    end

    test "applies a simple transformation" do
      script = """
      Map.put(ctx, :path, "/modified")
      """

      assert :ok = Transformations.set_script("tunnel-1", script)

      ctx = %{method: "GET", path: "/original", query_string: nil, headers: [], body: nil}
      assert {:ok, result} = Transformations.transform("tunnel-1", ctx)
      assert result.path == "/modified"
      assert result.method == "GET"
    end

    test "allows modifying headers" do
      script = """
      new_headers = [{"x-transformed", "true"} | ctx.headers]
      Map.put(ctx, :headers, new_headers)
      """

      assert :ok = Transformations.set_script("tunnel-1", script)

      ctx = %{method: "POST", path: "/api", query_string: nil, headers: [{"content-type", "application/json"}], body: ~s({"test": true})}
      assert {:ok, result} = Transformations.transform("tunnel-1", ctx)
      assert result.headers == [{"x-transformed", "true"}, {"content-type", "application/json"}]
    end

    test "allows JSON body transformation" do
      script = """
      decoded = Jason.decode!(ctx.body)
      new_body = Jason.encode!(Map.put(decoded, "injected", true))
      Map.put(ctx, :body, new_body)
      """

      assert :ok = Transformations.set_script("tunnel-1", script)

      ctx = %{method: "POST", path: "/api", query_string: nil, headers: [{"content-type", "application/json"}], body: ~s({"event": "push"})}
      assert {:ok, result} = Transformations.transform("tunnel-1", ctx)
      assert Jason.decode!(result.body) == %{"event" => "push", "injected" => true}
    end

    test "allows method transformation" do
      script = """
      Map.put(ctx, :method, "PUT")
      """

      assert :ok = Transformations.set_script("tunnel-1", script)

      ctx = %{method: "POST", path: "/api", query_string: nil, headers: [], body: nil}
      assert {:ok, result} = Transformations.transform("tunnel-1", ctx)
      assert result.method == "PUT"
    end

    test "allows query string transformation" do
      script = """
      Map.put(ctx, :query_string, "injected=true")
      """

      assert :ok = Transformations.set_script("tunnel-1", script)

      ctx = %{method: "GET", path: "/api", query_string: nil, headers: [], body: nil}
      assert {:ok, result} = Transformations.transform("tunnel-1", ctx)
      assert result.query_string == "injected=true"
    end

    test "returns error when script returns non-map" do
      script = """
      "not a map"
      """

      assert :ok = Transformations.set_script("tunnel-1", script)

      ctx = %{method: "GET", path: "/", query_string: nil, headers: [], body: nil}
      assert {:error, _reason} = Transformations.transform("tunnel-1", ctx)
    end

    test "returns error when script result is missing required keys" do
      script = """
      %{method: "GET"}
      """

      assert :ok = Transformations.set_script("tunnel-1", script)

      ctx = %{method: "GET", path: "/", query_string: nil, headers: [], body: nil}
      assert {:error, _reason} = Transformations.transform("tunnel-1", ctx)
    end

    test "returns error when script has syntax error" do
      script = """
      this is not valid elixir
      """

      assert :ok = Transformations.set_script("tunnel-1", script)

      ctx = %{method: "GET", path: "/", query_string: nil, headers: [], body: nil}
      assert {:error, _reason} = Transformations.transform("tunnel-1", ctx)
    end

    test "returns error when script raises exception" do
      script = """
      raise "boom"
      """

      assert :ok = Transformations.set_script("tunnel-1", script)

      ctx = %{method: "GET", path: "/", query_string: nil, headers: [], body: nil}
      assert {:error, _reason} = Transformations.transform("tunnel-1", ctx)
    end
  end
end