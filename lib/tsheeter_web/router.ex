defmodule TsheeterWeb.Router do
  use TsheeterWeb, :router
  import Phoenix.LiveDashboard.Router

  # basic auth plug can't be sent options at runtime and so requires hardcoded
  # compile-time credentials. this wrapper inserts them from runtime config.
  defmodule MyBasicAuth do
    def init(opts), do: opts
    def call(conn, opts) do
      runtime_opts = opts ++ Application.fetch_env!(:tsheeter, :basic_auth)
      Plug.BasicAuth.basic_auth(conn, runtime_opts)
    end
  end

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {TsheeterWeb.LayoutView, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :admins_only do
    if Mix.env() == :prod do
      plug MyBasicAuth
    end
  end

  scope "/", TsheeterWeb do
    pipe_through :browser

    get "/", PageController, :index
  end

  scope "/slack", TsheeterWeb do
    pipe_through :api
    post "/", SlackController, :interact
    post "/event", SlackController, :event
  end

  scope "/oauth", TsheeterWeb do
    pipe_through :browser
    live "/", OauthLive, :callback
  end

  scope "/" do
    pipe_through [:browser, :admins_only]
    live_dashboard "/dashboard", metrics: TsheeterWeb.Telemetry
  end
end
