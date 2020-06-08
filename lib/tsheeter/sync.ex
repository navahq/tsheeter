defmodule Tsheeter.Sync do
  use GenServer
  alias Tsheeter.Oauther
  alias Tsheeter.Repo
  alias Tsheeter.Token
  require Logger
  import Ecto.Query, only: [from: 2]

  @refresh_schedule 1_000 * 10 * 60   # (in ms) scan for tokens to refresh every 10 minutes
  @refresh_period   60 * 60 * 24      # (in seconds) refresh tokens 24 hours before they expire

  def start_link(_) do
    GenServer.start_link(__MODULE__, :initial_state)
  end

  def init(_) do
    Oauther.subscribe()
    send(self(), :refresh)
    {:ok, :no_state}
  end

  def schedule_refresh() do
    Process.send_after(self(), :refresh, @refresh_schedule)
  end

  def handle_info(:refresh, state) do
    refresh_tokens()
    schedule_refresh()
    {:noreply, state}
  end

  def handle_info({:got_token, id, %{access_token: access_token, expires_at: expires_at, refresh_token: refresh_token, user_id: user_id}}, state) do
    expires_at = DateTime.from_unix!(expires_at)
    attrs = %{
      slack_uid: id,
      tsheets_uid: String.to_integer(user_id),
      access_token: access_token,
      expires_at: expires_at,
      refresh_token: refresh_token
    }

    %Token{}
    |> Token.changeset(attrs)
    |> Repo.insert!(
      on_conflict: [
        set: [access_token: access_token, refresh_token: refresh_token, expires_at: expires_at]
      ],
      conflict_target: :slack_uid
    )

    {:noreply, state}
  end

  def handle_info(_, state), do: {:noreply, state}

  def refresh_tokens() do
    expire_max = DateTime.utc_now() |> DateTime.add(@refresh_period)
    tokens = Repo.all(from t in Token, where: t.expires_at <= ^expire_max)

    for token <- tokens do
      Oauther.create(token.slack_uid)
      Oauther.refresh(token.slack_uid, token.access_token, token.refresh_token)
    end
  end
end
