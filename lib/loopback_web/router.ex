defmodule LoopbackWeb.Router do
  use LoopbackWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {LoopbackWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", LoopbackWeb do
    pipe_through :browser

    get "/", PageController, :home

    live "/tunnels", TunnelListLive
    live "/tunnels/:id", TunnelDetailLive
  end

  scope "/api", LoopbackWeb do
    pipe_through :api

    post "/replays/:request_id", ReplayController, :replay
  end

  scope "/t", LoopbackWeb do
    pipe_through :api

    match :*, "/:tunnel_id/*path", TunnelController, :forward
  end

  if Application.compile_env(:loopback, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: LoopbackWeb.Telemetry
    end
  end
end
