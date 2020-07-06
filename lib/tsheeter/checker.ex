defmodule Tsheeter.Checker do
  use GenServer
  require Logger
  alias Tsheeter.Token
  alias Tsheeter.User
  alias Tsheeter.User.Timesheet

  # (in ms) scan every 60 seconds
  @refresh_schedule 1_000 * 60

  @via_registry {:via, Horde.Registry, {Tsheeter.Registry, __MODULE__}}

  defmodule Checks do
    defstruct missing_weekday_save: false,
              below_eight_hours: false,
              missing_friday_submit: false,
              missing_eom_submit_today: false,
              missing_eom_submit_soon: false
  end

  def create() do
    case Horde.DynamicSupervisor.start_child(Tsheeter.Supervisor, {__MODULE__, Time.utc_now()}) do
      {:ok, _} = response ->
        response

      {:error, {{:badmatch, {:error, {:already_started, pid}}}, _}} ->
        {:ok, pid}

      {:error, {:already_started, pid}} ->
        {:ok, pid}

      x ->
        x
    end
  end

  def start_link(state) do
    GenServer.start_link(__MODULE__, state, name: @via_registry)
  end

  def init(last_scan) do
    schedule_refresh()
    {:ok, last_scan}
  end

  def schedule_refresh() do
    Process.send_after(self(), :refresh, @refresh_schedule)
  end

  def check(uid), do: GenServer.call(@via_registry, {:check, uid})

  def handle_info(:refresh, last_scan) do
    last_scan = run(last_scan)
    schedule_refresh()
    {:noreply, last_scan}
  end

  def handle_info(_, state), do: {:noreply, state}

  def run(last_scan) do
    now = Time.utc_now()
    ids = Token.with_check_between(last_scan, now)

    for id <- ids do
      User.todays_timesheet(id)
      |> check_timesheet
    end

    now
  end

  def handle_call({:check, uid}, _from, state) do
    ts = User.todays_timesheet(uid)
    result = check_timesheet(ts)

    {:reply, {ts, result}, state}
  end

  def check_timesheet(%Timesheet{date: date, saved_hours: hours, submitted?: submitted}) do
    %Checks{
      missing_weekday_save: weekday?(date) and hours == 0,
      below_eight_hours: weekday?(date) and hours < 8.0,
      missing_friday_submit: friday?(date) and not submitted,
      missing_eom_submit_today: not submitted and date.day == Date.days_in_month(date),
      missing_eom_submit_soon: not submitted and date.day < Date.days_in_month(date) and
        (date.day + 1)..Date.days_in_month(date)
        |> Enum.map(fn day -> %Date{date | day: day} end)
        |> Enum.map(&weekday?/1)
        |> Enum.map(&not/1)
        |> Enum.all?()
    }
  end

  defp weekday?(date), do: Date.day_of_week(date) in 1..5
  defp friday?(date), do: Date.day_of_week(date) == 5
end
