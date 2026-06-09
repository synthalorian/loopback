defmodule Loopback.Transformations do
  @moduledoc """
  Public API for programmable request transformations.

  Transformations are user-defined Elixir scripts that modify incoming requests
  before they are forwarded to the tunnel target. Each tunnel can have at most
  one active transformation script.

  Scripts receive a `ctx` map with:
    * `:method` — HTTP method string (e.g. `"POST"`)
    * `:path` — request path string (e.g. `"/api/events"`)
    * `:query_string` — query string or `nil`
    * `:headers` — list of `{name, value}` tuples
    * `:body` — request body binary or `nil`

  The script must return a map with the same keys (modified or not).
  """

  alias Loopback.Transformations.Registry
  alias Loopback.Transformations.Script

  @doc """
  Creates or updates a transformation script for a tunnel.
  """
  @spec set_script(String.t(), String.t()) :: :ok
  def set_script(tunnel_id, script_text) when is_binary(tunnel_id) and is_binary(script_text) do
    Registry.set(tunnel_id, script_text)
  end

  @doc """
  Gets the transformation script for a tunnel, if any.
  """
  @spec get_script(String.t()) :: String.t() | nil
  def get_script(tunnel_id) when is_binary(tunnel_id) do
    Registry.get(tunnel_id)
  end

  @doc """
  Removes the transformation script for a tunnel.
  """
  @spec delete_script(String.t()) :: :ok
  def delete_script(tunnel_id) when is_binary(tunnel_id) do
    Registry.delete(tunnel_id)
  end

  @doc """
  Lists all tunnels that have transformation scripts.
  """
  @spec list_scripts() :: [{String.t(), String.t()}]
  def list_scripts do
    Registry.list()
  end

  @doc """
  Applies the tunnel's transformation script to a request context.

  Returns `{:ok, ctx}` with the (possibly) modified context, or `{:ok, ctx}`
  unchanged when the tunnel has no script. Returns `{:error, reason}` when the
  script fails to execute.

  ## Example context

      %{
        method: "POST",
        path: "/webhooks/github",
        query_string: "foo=bar",
        headers: [{"content-type", "application/json"}],
        body: ~s({"event": "push"})
      }
  """
  @spec transform(String.t(), map()) :: {:ok, map()} | {:error, term()}
  def transform(tunnel_id, ctx) when is_binary(tunnel_id) and is_map(ctx) do
    case Registry.get(tunnel_id) do
      nil ->
        {:ok, ctx}

      script_text ->
        Script.execute(script_text, ctx)
    end
  end
end