defmodule LoopbackWeb.PageControllerTest do
  use LoopbackWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, "/")
    assert html_response(conn, 200) =~ "Loopback"
  end
end
