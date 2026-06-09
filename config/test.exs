import Config

config :loopback, LoopbackWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "test-secret-key-base-change-in-production-1234567890abcdef1234567890abcdef1234567890abcdef",
  server: false

config :logger, level: :warning
