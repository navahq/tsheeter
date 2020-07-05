defmodule Tsheeter.Application do
  @moduledoc false

  use Application
  alias Tsheeter.Sync
  alias Tsheeter.Token
  alias Tsheeter.UserManager

  def start(_type, _args) do
    topologies = Application.get_env(:libcluster, :topologies)

    # in minimal configuration (for migrations), only start Repo
    children = [Tsheeter.Repo]
    ++ if !Application.get_env(:tsheeter, :minimal) do
      [
        {Cluster.Supervisor, [topologies, [name: Tsheeter.ClusterSupervisor]]},
        {Horde.Registry, [name: Tsheeter.Registry, keys: :unique]},
        {Horde.DynamicSupervisor, [name: Tsheeter.Supervisor, strategy: :one_for_one]},
        {Phoenix.PubSub, name: Tsheeter.PubSub},
        Tsheeter.SlackHome,
        TsheeterWeb.Telemetry,
        TsheeterWeb.Endpoint,
        %{id: Tsheeter.HordeConnector, restart: :transient, start: {Task, :start_link, [
          fn ->
            Horde.Cluster.set_members(Tsheeter.Registry, membership(Tsheeter.Registry, nodes()))
            Horde.Cluster.set_members(Tsheeter.Supervisor, membership(Tsheeter.Supervisor, nodes()))
          end ]}},
        {Task, &start_dynamic_procs/0}
      ]
    else
      []
    end

    opts = [strategy: :one_for_one, name: Tsheeter.MainSupervisor]
    Supervisor.start_link(children, opts)
  end

  def config_change(changed, _new, removed) do
    TsheeterWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp nodes(), do: [Node.self()] ++ Node.list()
  defp membership(horde, nodes), do: Enum.map(nodes, fn node -> {horde, node} end)

  defp start_dynamic_procs() do
    Sync.create
    for token <- Token.all() do
      UserManager.create(token)
    end
  end
end
