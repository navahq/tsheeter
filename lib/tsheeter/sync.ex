defmodule Tsheeter.Sync do
  use GenServer
  require Logger
  alias Tsheeter.Token
  alias Tsheeter.UserManager

  @refresh_schedule 1_000 * 60   # (in ms) scan every 60 seconds

  def start_link(_) do
    GenServer.start_link(__MODULE__, Time.utc_now())
  end

  def init(last_scan) do
    schedule_refresh()
    {:ok, last_scan}
  end

  def schedule_refresh() do
    Process.send_after(self(), :refresh, @refresh_schedule)
  end

  def handle_info(:refresh, last_scan) do
    last_scan = run(last_scan)
    schedule_refresh()
    {:noreply, last_scan}
  end

  def handle_info(_, state), do: {:noreply, state}

  def run(last_scan) do
    now = Time.utc_now
    ids = Token.with_check_between(last_scan, now)

    for id <- ids do
      result = UserManager.todays_timesheet(id)
      Logger.info "Result: #{inspect(result, pretty: true)}"
    end

    now
  end
end
