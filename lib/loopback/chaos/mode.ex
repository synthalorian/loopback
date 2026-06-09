defmodule Loopback.Chaos.Mode do
  @moduledoc """
  GenServer that manages chaos mode configuration and application.

  Supports per-tunnel and global chaos settings with configurable
  probabilities for:

    * **Delay** - randomly delay requests before forwarding
    * **Drop** - randomly drop requests (return 503)
    * **Corrupt** - randomly corrupt request bodies before forwarding

  Each behavior has a probability (0.0 to 1.0) and optional parameters.
  """

  use GenServer

  @name __MODULE__

  defstruct enabled: false,
            delay_probability: 0.0,
            delay_min_ms: 0,
            delay_max_ms: 1000,
            drop_probability: 0.0,
            corrupt_probability: 0.0,
            corrupt_max_bytes: 10

  @type t :: %__MODULE__{
          enabled: boolean(),
          delay_probability: float(),
          delay_min_ms: non_neg_integer(),
          delay_max_ms: non_neg_integer(),
          drop_probability: float(),
          corrupt_probability: float(),
          corrupt_max_bytes: non_neg_integer()
        }

  @type chaos_result :: :ok | {:error, :chaos_drop} | {:error, term()}

  # Client

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end

  @doc """
  Returns the current global chaos configuration.
  """
  @spec get_config() :: t()
  def get_config do
    GenServer.call(@name, :get_config)
  end

  @doc """
  Enables chaos mode globally.
  """
  @spec enable() :: :ok
  def enable do
    GenServer.call(@name, :enable)
  end

  @doc """
  Disables chaos mode globally.
  """
  @spec disable() :: :ok
  def disable do
    GenServer.call(@name, :disable)
  end

  @doc """
  Sets the global chaos configuration.

  `config` is a map with optional keys:
    * `:enabled` - boolean to enable/disable chaos
    * `:delay_probability` - float 0.0-1.0
    * `:delay_min_ms` - minimum delay in milliseconds
    * `:delay_max_ms` - maximum delay in milliseconds
    * `:drop_probability` - float 0.0-1.0
    * `:corrupt_probability` - float 0.0-1.0
    * `:corrupt_max_bytes` - maximum bytes to corrupt
  """
  @spec set_config(map()) :: :ok
  def set_config(%{} = config) do
    GenServer.call(@name, {:set_config, config})
  end

  @doc """
  Applies chaos effects to a request.

  Returns `{:ok, body}` with potentially corrupted body, or
  `{:error, :chaos_drop}` if the request should be dropped.
  """
  @spec apply_chaos(binary()) :: {:ok, binary()} | {:error, :chaos_drop}
  def apply_chaos(body) when is_binary(body) do
    GenServer.call(@name, {:apply_chaos, body})
  end

  @doc """
  Resets chaos configuration to defaults (disabled, zero probabilities).
  """
  @spec reset() :: :ok
  def reset do
    GenServer.call(@name, :reset)
  end

  # Server

  @impl true
  def init(_opts) do
    {:ok, %__MODULE__{}}
  end

  @impl true
  def handle_call(:get_config, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call(:enable, _from, state) do
    {:reply, :ok, %{state | enabled: true}}
  end

  @impl true
  def handle_call(:disable, _from, state) do
    {:reply, :ok, %{state | enabled: false}}
  end

  @impl true
  def handle_call({:set_config, config}, _from, state) do
    new_state =
      state
      |> maybe_put(:enabled, config[:enabled])
      |> maybe_put(:delay_probability, config[:delay_probability])
      |> maybe_put(:delay_min_ms, config[:delay_min_ms])
      |> maybe_put(:delay_max_ms, config[:delay_max_ms])
      |> maybe_put(:drop_probability, config[:drop_probability])
      |> maybe_put(:corrupt_probability, config[:corrupt_probability])
      |> maybe_put(:corrupt_max_bytes, config[:corrupt_max_bytes])

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:apply_chaos, body}, _from, state) do
    if not state.enabled do
      {:reply, {:ok, body}, state}
    else
      result = do_apply_chaos(body, state)
      {:reply, result, state}
    end
  end

  @impl true
  def handle_call(:reset, _from, _state) do
    {:reply, :ok, %__MODULE__{}}
  end

  # Private

  defp maybe_put(state, _key, nil), do: state
  defp maybe_put(state, key, value), do: Map.put(state, key, value)

  defp do_apply_chaos(body, state) do
    # Check drop first - if dropped, we don't delay or corrupt
    if should_trigger?(state.drop_probability) do
      {:error, :chaos_drop}
    else
      # Apply delay
      if should_trigger?(state.delay_probability) do
        delay_ms = random_in_range(state.delay_min_ms, state.delay_max_ms)
        Process.sleep(delay_ms)
      end

      # Apply corruption
      body =
        if should_trigger?(state.corrupt_probability) do
          corrupt_body(body, state.corrupt_max_bytes)
        else
          body
        end

      {:ok, body}
    end
  end

  defp should_trigger?(probability) do
    :rand.uniform() < probability
  end

  defp random_in_range(min, max) when min >= max, do: min

  defp random_in_range(min, max) do
    min + :rand.uniform(max - min + 1) - 1
  end

  defp corrupt_body("", _max_bytes), do: ""

  defp corrupt_body(body, max_bytes) when is_binary(body) do
    body_size = byte_size(body)

    if body_size == 0 do
      body
    else
      # Determine how many bytes to corrupt
      bytes_to_corrupt = min(max_bytes, max(1, div(body_size, 10)))
      bytes_to_corrupt = min(bytes_to_corrupt, body_size)

      # Corrupt random positions
      positions =
        0..(body_size - 1)
        |> Enum.take_random(bytes_to_corrupt)

      # Convert to charlist for mutation
      charlist = :binary.bin_to_list(body)

      corrupted_charlist =
        Enum.with_index(charlist, fn byte, idx ->
          if idx in positions do
            # Flip a random bit
            bit_to_flip = :rand.uniform(8) - 1
            Bitwise.bxor(byte, Bitwise.bsl(1, bit_to_flip))
          else
            byte
          end
        end)

      :binary.list_to_bin(corrupted_charlist)
    end
  end
end
