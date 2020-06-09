defmodule Tsheeter.Release do
  require Logger
  @app :tsheeter

  def migrate do
    load_app()

    for repo <- repos() do
      Logger.info "Migrating: #{inspect(repo, pretty: true)}"
      {:ok, a, b} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
      Logger.info "a: #{inspect(a, pretty: true)}"
      Logger.info "b: #{inspect(b, pretty: true)}"
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.load(@app)
  end
end
