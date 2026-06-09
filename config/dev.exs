import Config

config :loopback, LoopbackWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "dev-secret-key-base-change-in-production-1234567890abcdef",
  watchers: []

config :logger, :console, format: "[$level] $message\n"

config :loopback, dev_routes: true

config :phoenix, :stacktrace_depth, 20
config :phoenix, :plug_init_mode, :runtime
