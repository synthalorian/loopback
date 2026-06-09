defmodule Loopback.Chaos do
  @moduledoc """
  Public API for chaos mode.

  Chaos mode randomly introduces failures into the request forwarding pipeline
  to help test webhook consumers' resilience.

  Three behaviors are supported:

    * **Delay** - randomly delays requests before forwarding
    * **Drop** - randomly drops requests, returning HTTP 503
    * **Corrupt** - randomly flips bits in request bodies before forwarding

  Each behavior has a configurable probability (0.0 to 1.0).

  ## Examples

      # Enable chaos with 50% drop probability
      Loopback.Chaos.enable()
      Loopback.Chaos.set_config(drop_probability: 0.5)

      # Enable chaos with delay and corruption
      Loopback.Chaos.set_config(
        enabled: true,
        delay_probability: 0.3,
        delay_min_ms: 100,
        delay_max_ms: 2000,
        corrupt_probability: 0.1,
        corrupt_max_bytes: 5
      )

      # Disable chaos
      Loopback.Chaos.disable()

      # Reset to defaults
      Loopback.Chaos.reset()
  """

  alias Loopback.Chaos.Mode

  @doc """
  Returns the current chaos configuration.
  """
  @spec get_config() :: Mode.t()
  def get_config do
    Mode.get_config()
  end

  @doc """
  Enables chaos mode.
  """
  @spec enable() :: :ok
  def enable do
    Mode.enable()
  end

  @doc """
  Disables chaos mode.
  """
  @spec disable() :: :ok
  def disable do
    Mode.disable()
  end

  @doc """
  Sets chaos configuration.

  ## Options

    * `:enabled` - boolean
    * `:delay_probability` - float 0.0-1.0
    * `:delay_min_ms` - minimum delay in milliseconds
    * `:delay_max_ms` - maximum delay in milliseconds
    * `:drop_probability` - float 0.0-1.0
    * `:corrupt_probability` - float 0.0-1.0
    * `:corrupt_max_bytes` - maximum bytes to corrupt per request
  """
  @spec set_config(keyword() | map()) :: :ok
  def set_config(opts) when is_list(opts) do
    Mode.set_config(Map.new(opts))
  end

  def set_config(%{} = config) do
    Mode.set_config(config)
  end

  @doc """
  Applies chaos effects to a request body.

  Returns `{:ok, body}` with potential corruption applied, or
  `{:error, :chaos_drop}` if the request should be dropped.
  """
  @spec apply_chaos(binary()) :: {:ok, binary()} | {:error, :chaos_drop}
  def apply_chaos(body) when is_binary(body) do
    Mode.apply_chaos(body)
  end

  @doc """
  Resets chaos configuration to defaults (all disabled).
  """
  @spec reset() :: :ok
  def reset do
    Mode.reset()
  end
end
