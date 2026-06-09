defmodule LoopbackWeb.TransformationsController do
  @moduledoc """
  API controller for managing tunnel transformation scripts.
  """

  use LoopbackWeb, :controller

  alias Loopback.Transformations

  def show(conn, %{"tunnel_id" => tunnel_id}) do
    case Transformations.get_script(tunnel_id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "no transformation script found for this tunnel"})

      script_text ->
        json(conn, %{tunnel_id: tunnel_id, script: script_text})
    end
  end

  def create(conn, %{"tunnel_id" => tunnel_id, "script" => script_text}) do
    :ok = Transformations.set_script(tunnel_id, script_text)

    conn
    |> put_status(:created)
    |> json(%{tunnel_id: tunnel_id, script: script_text})
  end

  def create(conn, %{"tunnel_id" => _tunnel_id}) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "missing required field: script"})
  end

  def delete(conn, %{"tunnel_id" => tunnel_id}) do
    :ok = Transformations.delete_script(tunnel_id)

    send_resp(conn, :no_content, "")
  end
end