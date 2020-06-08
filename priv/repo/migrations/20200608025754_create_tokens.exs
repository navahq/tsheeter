defmodule Tsheeter.Repo.Migrations.CreateTokens do
  use Ecto.Migration

  def change do
    create table(:tokens) do
      add :slack_uid, :string
      add :tsheets_uid, :integer
      add :access_token, :string
      add :refresh_token, :string
      add :expires_at, :utc_datetime

      timestamps()
    end

    create unique_index(:tokens, [:slack_uid])
  end
end
