import Config

database_url =
  System.get_env("DATABASE_URL") ||
    raise """
    environment variable DATABASE_URL is missing.
    For example: ecto://USER:PASS@HOST/DATABASE
    """

config :tsheeter, Tsheeter.Repo,
  # ssl: true,
  url: database_url,
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")

secret_key_base =
  System.get_env("SECRET_KEY_BASE") ||
    raise """
    environment variable SECRET_KEY_BASE is missing.
    You can generate one by calling: mix phx.gen.secret
    """

config :tsheeter, TsheeterWeb.Endpoint,
  http: [
    port: String.to_integer(System.get_env("PORT") || "4000"),
    transport_options: [socket_opts: [:inet6]]
  ],
  secret_key_base: secret_key_base,
  check_origin: ["//tsheeter.dgoeke.io"]

admin_username =
  System.get_env("ADMIN_USERNAME") ||
    raise """
    environment variable ADMIN_USERNAME is missing.
    """

admin_password =
  System.get_env("ADMIN_PASSWORD") ||
    raise """
    environment variable ADMIN_PASSWORD is missing.
    """

config :tsheeter, :basic_auth,
  username: admin_username,
  password: admin_password

slack_verify_token =
  System.get_env("SLACK_VERIFICATION_TOKEN") ||
    raise "environment variable SLACK_VERIFICATION_TOKEN is missing"

config :tsheeter,
  slack_verify_token: slack_verify_token

slack_bot_token =
  System.get_env("SLACK_BOT_TOKEN") ||
    raise "environment variable SLACK_BOT_TOKEN is missing"

config :tsheeter,
  slack_bot_token: slack_bot_token

oauth_client_id =
  System.get_env("OAUTH_CLIENT_ID") ||
    raise "environment variable OAUTH_CLIENT_ID is missing"

oauth_client_secret =
  System.get_env("OAUTH_CLIENT_SECRET") ||
    raise "environment variable OAUTH_CLIENT_SECRET is missing"

config :tsheeter, :oauth,
  strategy: OAuth2.Strategy.AuthCode,
  client_id: oauth_client_id,
  client_secret: oauth_client_secret,
  redirect_uri: "https://tsheeter.dgoeke.io/oauth",
  site: "https://rest.tsheets.com",
  authorize_url: "/api/v1/authorize",
  token_url: "/api/v1/grant"
