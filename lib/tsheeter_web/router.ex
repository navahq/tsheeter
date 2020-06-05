defmodule TsheeterWeb.Router do
  use TsheeterWeb, :router
  import Phoenix.LiveDashboard.Router

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

  scope "/", TsheeterWeb do
    pipe_through :browser

    get "/", PageController, :index
    live_dashboard "/dashboard", metrics: TsheeterWeb.Telemetry
  end

  scope "/slack", TsheeterWeb do
    pipe_through :api
    post "/", SlackController, :interact
    post "/event", SlackController, :event
  end
end
