defmodule Loopback.Captures.Request do
  @moduledoc """
  Struct representing a captured webhook request and its response.
  """

  @enforce_keys [:id, :tunnel_id, :method, :path, :inserted_at]
  defstruct [
    :id,
    :tunnel_id,
    :method,
    :path,
    :query_string,
    :headers,
    :body,
    :response_status,
    :response_headers,
    :response_body,
    :inserted_at
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          tunnel_id: String.t(),
          method: String.t(),
          path: String.t(),
          query_string: String.t() | nil,
          headers: [{String.t(), String.t()}],
          body: binary() | nil,
          response_status: integer() | nil,
          response_headers: [{String.t(), String.t()}] | nil,
          response_body: binary() | nil,
          inserted_at: DateTime.t()
        }
end
