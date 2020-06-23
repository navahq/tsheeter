defmodule Tsheeter.Repo.Migrations.AddSchedule do
  use Ecto.Migration

  def change do
    alter table(:tokens) do
      add :check_saved_schedule, :map
      add :check_submitted_schedule, :map
    end
  end
end
