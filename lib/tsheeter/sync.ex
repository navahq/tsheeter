defmodule Tsheeter.Sync do
  use GenServer
  alias Tsheeter.Oauther
  alias Tsheeter.Token
  require Logger

  @refresh_schedule 1_000 * 10 * 60   # (in ms) scan for tokens to refresh every 10 minutes
  @topic "tokens"

  def start_link(_) do
    GenServer.start_link(__MODULE__, :initial_state)
  end

  def init(_) do
    Oauther.subscribe()
    schedule_refresh()
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

    token = Token.insert!(attrs)
    broadcast({:token_available, token})
    {:noreply, state}
  end

  def handle_info(_, state), do: {:noreply, state}

  def refresh_tokens() do
    for token <- Token.all_expiring() do
      Oauther.create(token.slack_uid)
      Oauther.refresh(token.slack_uid, token.access_token, token.refresh_token)
    end
  end

  defp broadcast(data) do
    Phoenix.PubSub.broadcast(Tsheeter.PubSub, @topic, data)
  end

  def subscribe() do
    Phoenix.PubSub.subscribe(Tsheeter.PubSub, @topic)
  end
end
