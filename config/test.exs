use Mix.Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :tsheeter, Tsheeter.Repo,
  username: "postgres",
  password: "postgres",
  database: "tsheeter_test#{System.get_env("MIX_TEST_PARTITION")}",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :tsheeter, TsheeterWeb.Endpoint,
  http: [port: 4002],
  server: false

# Print only warnings and errors during test
config :logger, level: :warn

config :libcluster,
  topologies: []

config :tsheeter, :oauth,
  client_id: "client_id",
  client_secret: "client_secret",
  redirect_uri: "http://localhost:4000/oauth"

config :tsheeter,
  slack_verify_token: System.get_env("SLACK_VERIFICATION_TOKEN")

config :tsheeter,
  slack_bot_token: System.get_env("SLACK_BOT_TOKEN")

config :tsheeter, :oauth,
  strategy: OAuth2.Strategy.AuthCode,
  client_id: System.get_env("OAUTH_CLIENT_ID"),
  client_secret: System.get_env("OAUTH_CLIENT_SECRET"),
  redirect_uri: "http://localhost:4000/oauth",
  site: "https://rest.tsheets.com",
  authorize_url: "/api/v1/authorize",
  token_url: "/api/v1/grant"
