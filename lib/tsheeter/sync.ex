defmodule Tsheeter.Sync do
  use GenServer
  alias Tsheeter.UserManager
  alias Tsheeter.Token
  require Logger

  @refresh_schedule 1_000 * 10 * 60   # (in ms) scan for tokens to refresh every 10 minutes

  def start_link(_) do
    GenServer.start_link(__MODULE__, :initial_state)
  end

  def init(_) do
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

  def handle_info(_, state), do: {:noreply, state}

  def refresh_tokens() do
    for token <- Token.all_expiring() do
      UserManager.refresh_token(token.slack_uid)
    end
  end
end
