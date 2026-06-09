import Config

config :loopback, LoopbackWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: LoopbackWeb.ErrorHTML, json: LoopbackWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Loopback.PubSub,
  live_view: [signing_salt: "change-me-in-production"]

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, Jason

import_config "#{config_env()}.exs"
