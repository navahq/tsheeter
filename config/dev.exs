use Mix.Config

# Configure your database
config :tsheeter, Tsheeter.Repo,
  username: "postgres",
  password: "postgres",
  database: "tsheeter_dev",
  hostname: "localhost",
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

# For development, we disable any cache and enable
# debugging and code reloading.
#
# The watchers configuration can be used to run external
# watchers to your application. For example, we use it
# with webpack to recompile .js and .css sources.
config :tsheeter, TsheeterWeb.Endpoint,
  http: [
    port: String.to_integer(System.get_env("PORT") || "4000"),
  ],
  debug_errors: true,
  code_reloader: true,
  check_origin: false,
  watchers: [
    node: [
      "node_modules/webpack/bin/webpack.js",
      "--mode",
      "development",
      "--watch-stdin",
      cd: Path.expand("../assets", __DIR__)
    ]
  ]

# Watch static and templates for browser reloading.
config :tsheeter, TsheeterWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/tsheeter_web/(live|views)/.*(ex)$",
      ~r"lib/tsheeter_web/templates/.*(eex)$"
    ]
  ]

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime

config :libcluster,
  topologies: [
    epmd: [
      strategy: Cluster.Strategy.Epmd,
      config: [
        hosts:
          with {:ok, names} <- :net_adm.names(),
               {:ok, host} <- :inet.gethostname() do
            names
            |> Enum.map(fn {name, _} -> :"#{name}@#{host}" end)
            |> Enum.reject(fn e -> is_nil(e) end)
          else
            _ -> []
          end
      ]
    ]
  ]

config :oauth2, debug: true

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
