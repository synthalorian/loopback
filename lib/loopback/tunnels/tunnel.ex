defmodule Loopback.Tunnels.Tunnel do
  @moduledoc """
  Tunnel data model.
  """

  @enforce_keys [:id, :target_url]
  defstruct [:id, :target_url, :inserted_at]

  @type t :: %__MODULE__{
          id: String.t(),
          target_url: String.t(),
          inserted_at: DateTime.t()
        }
end
