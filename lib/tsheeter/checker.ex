defmodule Tsheeter.Checker do
  use GenServer
  require Logger
  alias Tsheeter.Token
  alias Tsheeter.User
  alias Tsheeter.User.Timesheet

  # (in ms) scan every 60 seconds
  @refresh_schedule 1_000 * 60

  @via_registry {:via, Horde.Registry, {Tsheeter.Registry, __MODULE__}}

  @missing_weekday_save_msg     "your timesheet hasn't been saved today."
  @below_eight_hours_msg        "your timesheet has some data today, but it's less than eight hours."
  @missing_friday_submit_msg    "your timesheet hasn't been submitted (today is Friday)."
  @missing_eom_submit_today_msg "your timesheet hasn't been submitted (today is the last day of the month)."
  @missing_eom_submit_soon_msg  "your timesheet hasn't been submitted (today is the last working day of the month)."

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
      |> check_timesheet()
      |> generate_message()
      |> send_notification(id)
    end

    now
  end

  def handle_call({:check, uid}, _from, state) do
    ts = User.todays_timesheet(uid)
    result = check_timesheet(ts)

    {:reply, {ts, result}, state}
  end

  def check_timesheet(%Timesheet{date: date, saved_hours: hours, submitted?: submitted}) do
    if not weekday?(date),
      do: %Checks{},
      else: %Checks{
        missing_weekday_save: hours == 0,
        below_eight_hours: hours < 8.0,
        missing_friday_submit: not submitted and friday?(date),
        missing_eom_submit_today: not submitted and date.day == Date.days_in_month(date),
        missing_eom_submit_soon:
          not submitted and date.day < Date.days_in_month(date) and
            (date.day + 1)..Date.days_in_month(date)
            |> Enum.map(fn day -> %Date{date | day: day} end)
            |> Enum.map(&weekday?/1)
            |> Enum.map(&not/1)
            |> Enum.all?()
      }
  end

  def generate_message(%Checks{} = checks) do
    msg =
      [need_save_msg(checks), need_submit_msg(checks)]
      |> Enum.filter(fn msg -> msg end)
      |> Enum.join(" Also, ")
      |> upcase_first_letter()

    if msg == "", do: nil, else: msg
  end

  defp send_notification(nil, _id), do: nil
  defp send_notification(msg, id) do
    User.send_message(id, msg)
  end

  defp weekday?(date), do: Date.day_of_week(date) in 1..5
  defp friday?(date), do: Date.day_of_week(date) == 5

  defp need_save_msg(%Checks{missing_weekday_save: false, below_eight_hours: false}), do: nil
  defp need_save_msg(%Checks{missing_weekday_save: true}), do: @missing_weekday_save_msg
  defp need_save_msg(%Checks{below_eight_hours: true}), do: @below_eight_hours_msg

  defp need_submit_msg(%Checks{missing_friday_submit: false, missing_eom_submit_today: false, missing_eom_submit_soon: false}), do: nil
  defp need_submit_msg(%Checks{missing_eom_submit_today: true}), do: @missing_eom_submit_today_msg
  defp need_submit_msg(%Checks{missing_eom_submit_soon: true}), do: @missing_eom_submit_soon_msg
  defp need_submit_msg(%Checks{missing_friday_submit: true}), do: @missing_friday_submit_msg

  defp upcase_first_letter(""), do: ""
  defp upcase_first_letter(<<first::utf8, rest::binary>>), do: String.upcase(<<first::utf8>>) <> rest
end
