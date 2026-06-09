defmodule Loopback.ChaosTest do
  use ExUnit.Case, async: false

  alias Loopback.Chaos

  setup do
    Chaos.reset()
    :ok
  end

  describe "get_config/0" do
    test "returns default config with chaos disabled" do
      config = Chaos.get_config()
      assert config.enabled == false
      assert config.delay_probability == 0.0
      assert config.drop_probability == 0.0
      assert config.corrupt_probability == 0.0
    end
  end

  describe "enable/0 and disable/0" do
    test "enables chaos mode" do
      assert :ok = Chaos.enable()
      assert Chaos.get_config().enabled == true
    end

    test "disables chaos mode" do
      Chaos.enable()
      assert :ok = Chaos.disable()
      assert Chaos.get_config().enabled == false
    end
  end

  describe "set_config/1" do
    test "sets configuration from keyword list" do
      assert :ok =
               Chaos.set_config(
                 enabled: true,
                 delay_probability: 0.5,
                 delay_min_ms: 100,
                 delay_max_ms: 500,
                 drop_probability: 0.3,
                 corrupt_probability: 0.1,
                 corrupt_max_bytes: 5
               )

      config = Chaos.get_config()
      assert config.enabled == true
      assert config.delay_probability == 0.5
      assert config.delay_min_ms == 100
      assert config.delay_max_ms == 500
      assert config.drop_probability == 0.3
      assert config.corrupt_probability == 0.1
      assert config.corrupt_max_bytes == 5
    end

    test "sets configuration from map" do
      assert :ok = Chaos.set_config(%{enabled: true, drop_probability: 0.75})
      config = Chaos.get_config()
      assert config.enabled == true
      assert config.drop_probability == 0.75
    end

    test "partial update preserves existing values" do
      Chaos.set_config(enabled: true, delay_probability: 0.5)
      Chaos.set_config(drop_probability: 0.3)

      config = Chaos.get_config()
      assert config.enabled == true
      assert config.delay_probability == 0.5
      assert config.drop_probability == 0.3
    end
  end

  describe "apply_chaos/1 when disabled" do
    test "returns body unchanged when chaos is disabled" do
      body = "test body"
      assert {:ok, ^body} = Chaos.apply_chaos(body)
    end
  end

  describe "apply_chaos/1 with drop" do
    test "always drops when probability is 1.0" do
      Chaos.set_config(enabled: true, drop_probability: 1.0)
      assert {:error, :chaos_drop} = Chaos.apply_chaos("test")
    end

    test "never drops when probability is 0.0" do
      Chaos.set_config(enabled: true, drop_probability: 0.0)
      assert {:ok, "test"} = Chaos.apply_chaos("test")
    end
  end

  describe "apply_chaos/1 with delay" do
    test "delays requests when probability is 1.0" do
      Chaos.set_config(
        enabled: true,
        delay_probability: 1.0,
        delay_min_ms: 50,
        delay_max_ms: 60
      )

      before = System.monotonic_time(:millisecond)
      assert {:ok, "test"} = Chaos.apply_chaos("test")
      after_ms = System.monotonic_time(:millisecond)

      assert after_ms - before >= 45
    end
  end

  describe "apply_chaos/1 with corruption" do
    test "corrupts body when probability is 1.0" do
      Chaos.set_config(
        enabled: true,
        corrupt_probability: 1.0,
        corrupt_max_bytes: 10
      )

      original = "hello world"
      assert {:ok, corrupted} = Chaos.apply_chaos(original)
      assert corrupted != original
      assert byte_size(corrupted) == byte_size(original)
    end

    test "does not corrupt empty body" do
      Chaos.set_config(
        enabled: true,
        corrupt_probability: 1.0,
        corrupt_max_bytes: 10
      )

      assert {:ok, ""} = Chaos.apply_chaos("")
    end

    test "never corrupts when probability is 0.0" do
      Chaos.set_config(enabled: true, corrupt_probability: 0.0)
      body = "unchanged"
      assert {:ok, ^body} = Chaos.apply_chaos(body)
    end
  end

  describe "apply_chaos/1 combined behaviors" do
    test "drop takes precedence over delay and corrupt" do
      Chaos.set_config(
        enabled: true,
        drop_probability: 1.0,
        delay_probability: 1.0,
        corrupt_probability: 1.0
      )

      # Should drop, not delay or corrupt
      assert {:error, :chaos_drop} = Chaos.apply_chaos("test")
    end

    test "delay and corrupt can both apply" do
      Chaos.set_config(
        enabled: true,
        drop_probability: 0.0,
        delay_probability: 1.0,
        delay_min_ms: 30,
        delay_max_ms: 40,
        corrupt_probability: 1.0,
        corrupt_max_bytes: 5
      )

      before = System.monotonic_time(:millisecond)
      assert {:ok, corrupted} = Chaos.apply_chaos("hello world")
      after_ms = System.monotonic_time(:millisecond)

      assert after_ms - before >= 25
      assert corrupted != "hello world"
    end
  end

  describe "reset/0" do
    test "resets configuration to defaults" do
      Chaos.set_config(
        enabled: true,
        delay_probability: 0.5,
        drop_probability: 0.3,
        corrupt_probability: 0.1
      )

      assert :ok = Chaos.reset()

      config = Chaos.get_config()
      assert config.enabled == false
      assert config.delay_probability == 0.0
      assert config.drop_probability == 0.0
      assert config.corrupt_probability == 0.0
      assert config.delay_min_ms == 0
      assert config.delay_max_ms == 1000
      assert config.corrupt_max_bytes == 10
    end
  end
end
