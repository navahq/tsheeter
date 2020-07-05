defmodule Tsheeter.Repo.Migrations.AddCheckHour do
  use Ecto.Migration

  @default_check_time "20:30:00"  # 4:30 pm eastern expressed in UTC

  def up do
    alter table(:tokens) do
      add :check_time, :time, null: false, default: @default_check_time
      remove :check_saved_schedule
      remove :check_submitted_schedule
    end

    create index(:tokens, [:check_time])
  end

  def down do

    alter table(:tokens) do
      add :check_saved_schedule, :map
      add :check_submitted_schedule, :map
      remove :check_time
    end
  end
end
