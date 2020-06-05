defmodule TsheeterWeb.Router do
  use TsheeterWeb, :router
  import Phoenix.LiveDashboard.Router
  import Plug.BasicAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :admins_only do
    plug :basic_auth, Application.fetch_env!(:tsheeter, :basic_auth)
  end

  scope "/", TsheeterWeb do
    pipe_through :browser

    get "/", PageController, :index
  end

  scope "/" do
    pipe_through [:browser, :admins_only]
    live_dashboard "/dashboard", metrics: TsheeterWeb.Telemetry
  end

  scope "/slack", TsheeterWeb do
    pipe_through :api
    post "/", SlackController, :interact
    post "/event", SlackController, :event
  end
end
