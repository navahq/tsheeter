defmodule Tsheeter.Token do
  use Ecto.Schema
  alias Tsheeter.Repo
  alias Tsheeter.Token
  import Ecto.Changeset
  import Ecto.Query, only: [from: 2]

  # (in seconds) refresh tokens 24 hours before they expire
  @expire_period 60 * 60 * 24
  @topic "tokens"

  schema "tokens" do
    field :access_token, :string
    field :expires_at, :utc_datetime
    field :refresh_token, :string
    field :slack_uid, :string
    field :tsheets_uid, :integer
    field :check_time, :time

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

  def store_from_oauth!(slack_uid, %OAuth2.AccessToken{
        access_token: access_token,
        expires_at: expires_at,
        refresh_token: refresh_token,
        other_params: %{"user_id" => user_id}
      }) do
    expires_at = DateTime.from_unix!(expires_at)

    %Token{}
    |> Token.changeset(%{
      slack_uid: slack_uid,
      tsheets_uid: String.to_integer(user_id),
      access_token: access_token,
      expires_at: expires_at,
      refresh_token: refresh_token
    })
    |> Repo.insert!(
      on_conflict: [
        set: [access_token: access_token, refresh_token: refresh_token, expires_at: expires_at]
      ],
      conflict_target: :slack_uid)

    get_by_slack_id(slack_uid)
    |> broadcast()
  end

  def error!(slack_uid, action, result) do
    Phoenix.PubSub.broadcast(Tsheeter.PubSub, @topic, {:error, %{slack_uid: slack_uid, action: action, result: result}})
  end

  def delete!(token), do: Repo.delete!(token)

  defp broadcast(%Token{} = token) do
    Phoenix.PubSub.broadcast(Tsheeter.PubSub, @topic, {:token, token})
    token
  end

  def subscribe() do
    Phoenix.PubSub.subscribe(Tsheeter.PubSub, @topic)
  end

  def all(), do: Repo.all(Token)

  def to_time(hour, minute, timezone) do
    t = DateTime.utc_now |> DateTime.shift_zone!(timezone)
    t = %{ t | hour: hour, minute: minute, microsecond: {0, 0}, second: 0}

    t |> DateTime.shift_zone!("UTC") |> DateTime.to_time
  end

  def to_timezone(%Time{hour: hour, minute: minute, second: second, microsecond: microsecond}, timezone) do
    t = DateTime.utc_now()
    t = %{ t | hour: hour, minute: minute, microsecond: microsecond, second: second}
    t |> DateTime.shift_zone!(timezone) |> DateTime.to_time
  end

  def set_check_time(id, time) do
    {1, _} =
      from(t in Token, where: t.slack_uid == ^id)
      |> Repo.update_all(set: [check_time: time])
  end

  def with_check_between(t1, t2) do
    query =
      from t in Token,
        where: t.check_time > ^t1 and t.check_time <= ^t2,
        select: [t.slack_uid]

    Repo.all(query)
  end
end
