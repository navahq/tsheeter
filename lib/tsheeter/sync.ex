defmodule Tsheeter.Sync do
  use GenServer
  require Logger

  @refresh_schedule 1_000 * 60   # (in ms) scan every 60 seconds

  def start_link(_) do
    GenServer.start_link(__MODULE__, DateTime.utc_now())
  end

  def init(state) do
    schedule_refresh()
    {:ok, state}
  end

  def schedule_refresh() do
    Process.send_after(self(), :refresh, @refresh_schedule)
  end

  def handle_info(:refresh, state) do
    run(state)
    schedule_refresh()
    {:noreply, state}
  end

  def handle_info(_, state), do: {:noreply, state}

  def run(_last_refresh) do
  end
end
