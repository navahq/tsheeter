defmodule TsheeterWeb.Router do
  use TsheeterWeb, :router
  import Phoenix.LiveDashboard.Router
  import Plug.BasicAuth

  @admin_username System.get_env("ADMIN_USERNAME")
  @admin_password System.get_env("ADMIN_PASSWORD")

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
    if Mix.env() == :prod do
      plug :basic_auth, username: @admin_username, password: @admin_password
    end
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
