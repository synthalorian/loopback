defmodule Loopback.Tunnels do
  @moduledoc """
  Public API for managing tunnels.
  """

  alias Loopback.Tunnels.Registry
  alias Loopback.Tunnels.Tunnel

  @doc """
  Creates a new tunnel forwarding to `target_url`.
  """
  @spec create_tunnel(String.t()) :: {:ok, Tunnel.t()}
  def create_tunnel(target_url) when is_binary(target_url) do
    Registry.create(target_url)
  end

  @doc """
  Fetches a tunnel by id.
  """
  @spec get_tunnel(String.t()) :: Tunnel.t() | nil
  def get_tunnel(id) when is_binary(id) do
    Registry.get(id)
  end

  @doc """
  Lists all tunnels ordered by creation time.
  """
  @spec list_tunnels() :: [Tunnel.t()]
  def list_tunnels do
    Registry.list()
  end

  @doc """
  Deletes a tunnel by id.
  """
  @spec delete_tunnel(String.t()) :: :ok
  def delete_tunnel(id) when is_binary(id) do
    Registry.delete(id)
  end
end
