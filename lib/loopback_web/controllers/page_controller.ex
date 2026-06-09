defmodule LoopbackWeb.PageController do
  use LoopbackWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
