import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :paw_mon, PawMonWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "datvNyHnrOZD5UUISOL1dE69JUiWvzBVfjXXgXeaJe1100sTEG9Mlka385HCZQ+l",
  server: false

# Print only warnings and errors during test
config :logger, level: :warn

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime
