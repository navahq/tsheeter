defmodule Tsheeter.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      Tsheeter.Repo,
      TsheeterWeb.Telemetry,
      {Phoenix.PubSub, name: Tsheeter.PubSub},
      TsheeterWeb.Endpoint,
    ]

    opts = [strategy: :one_for_one, name: Tsheeter.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def config_change(changed, _new, removed) do
    TsheeterWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
