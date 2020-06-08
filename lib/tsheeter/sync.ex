defmodule Tsheeter.Sync do
  use GenServer
  alias Tsheeter.Oauther
  alias Tsheeter.Repo
  alias Tsheeter.Token
  require Logger

  def start_link(_) do
    GenServer.start_link(__MODULE__, :initial_state)
  end

  def init(_) do
    Oauther.subscribe()
    {:ok, :no_state}
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
end
