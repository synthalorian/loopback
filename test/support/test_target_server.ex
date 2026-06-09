defmodule Loopback.TestTargetServer do
  @moduledoc """
  Test-only Plug server that echoes back request details.
  """

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    {:ok, body, conn} = Plug.Conn.read_body(conn)

    echoed = %{
      method: conn.method,
      path: conn.request_path,
      query_string: conn.query_string,
      headers: conn.req_headers |> Enum.into(%{}),
      body: body
    }

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(echoed))
  end

  def start do
    Bandit.start_link(plug: __MODULE__, port: 0, scheme: :http)
  end

  def url(pid) do
    {:ok, {_, port}} = ThousandIsland.listener_info(pid)
    "http://127.0.0.1:#{port}"
  end
end
