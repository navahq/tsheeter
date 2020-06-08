defmodule Tsheeter.Token do
  use Ecto.Schema
  import Ecto.Changeset

  schema "tokens" do
    field :access_token, :string
    field :expires_at, :utc_datetime
    field :refresh_token, :string
    field :slack_uid, :string
    field :tsheets_uid, :integer

    timestamps()
  end

  @doc false
  def changeset(token, attrs) do
    token
    |> cast(attrs, [:slack_uid, :tsheets_uid, :access_token, :refresh_token, :expires_at])
    |> validate_required([:slack_uid, :tsheets_uid, :access_token, :refresh_token, :expires_at])
    |> unique_constraint(:slack_uid)
  end
end
