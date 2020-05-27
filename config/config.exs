# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

config :tsheeter,
  ecto_repos: [Tsheeter.Repo]

# Configures the endpoint
config :tsheeter, TsheeterWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "9DbvVvTlpPJmhWkS0ItVyIDWT/h1EK216muXZnPtmsX3hY3661r2DzyV0svA/BFP",
  render_errors: [view: TsheeterWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: Tsheeter.PubSub,
  live_view: [signing_salt: "PRRfJVCL"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"

if Mix.env() != :prod do
  config :git_hooks,
    verbose: true,
    hooks: [
      pre_commit: [
        tasks: [
          "mix clean",
          "mix compile --warnings-as-errors",
          "mix format --check-formatted",
          "mix test"
        ]
      ]
    ]
end