defmodule Tsheeter.Token do
  use Ecto.Schema
  alias Tsheeter.Repo
  alias Tsheeter.Token
  import Ecto.Changeset
  import Ecto.Query, only: [from: 2]

  @expire_period 60 * 60 * 24   # (in seconds) refresh tokens 24 hours before they expire

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

  def get_by_slack_id(slack_id) do
    query = from t in Token, where: t.slack_uid == ^slack_id
    case Repo.all(query) do
      [item] -> item
      [] -> nil
    end
  end

  def all_expiring() do
    expire_max = DateTime.utc_now() |> DateTime.add(@expire_period)
    Repo.all(from t in Token, where: t.expires_at <= ^expire_max)
  end

  def insert!(attrs = %{access_token: access_token, expires_at: expires_at, refresh_token: refresh_token}) do
    %Token{}
    |> Token.changeset(attrs)
    |> Repo.insert!(
      on_conflict: [
        set: [access_token: access_token, refresh_token: refresh_token, expires_at: expires_at]
      ],
      conflict_target: :slack_uid
    )
  end

  def delete!(token), do: Repo.delete!(token)
end
