defmodule CheckerTest do
  use ExUnit.Case
  alias Tsheeter.Checker
  alias Tsheeter.User.Timesheet

  defp submitted(%Timesheet{} = ts), do: %{ts | submitted?: true}

  defp with_hours(%Timesheet{} = ts, hours), do: %{ts | saved_hours: hours}

  defp with_date(%Timesheet{} = ts, y, m, d) do
    {:ok, d} = Date.new(y, m, d)
    %{ts | date: d}
  end

  defp with_wednesday(%Timesheet{} = ts), do: with_date(ts, 2020, 1, 1)
  defp with_saturday(%Timesheet{} = ts), do: with_date(ts, 2020, 1, 4)
  defp with_friday(%Timesheet{} = ts), do: with_date(ts, 2020, 1, 3)
  defp with_eom(%Timesheet{} = ts), do: with_date(ts, 2020, 1, 31)
  defp with_eom_soon(%Timesheet{} = ts), do: with_date(ts, 2020, 2, 28)

  test "weekday save" do
    ts = %Timesheet{} |> with_wednesday()
    assert Checker.check_timesheet(ts).missing_weekday_save

    ts = %Timesheet{} |> with_wednesday() |> with_hours(8)
    assert not Checker.check_timesheet(ts).missing_weekday_save

    ts = %Timesheet{} |> with_saturday()
    assert not Checker.check_timesheet(ts).missing_weekday_save
  end

  test "missing friday submit" do
    ts = %Timesheet{} |> with_friday()
    assert Checker.check_timesheet(ts).missing_friday_submit

    ts = %Timesheet{} |> with_wednesday()
    assert not Checker.check_timesheet(ts).missing_friday_submit

    ts = %Timesheet{} |> with_friday() |> submitted()
    assert not Checker.check_timesheet(ts).missing_friday_submit
  end

  test "missing eom today submit" do
    ts = %Timesheet{} |> with_eom()
    assert Checker.check_timesheet(ts).missing_eom_submit_today

    ts = %Timesheet{} |> with_eom() |> submitted()
    assert not Checker.check_timesheet(ts).missing_eom_submit_today

    ts = %Timesheet{} |> with_wednesday()
    assert not Checker.check_timesheet(ts).missing_eom_submit_today
  end

  test "missing eom soon submit" do
    ts = %Timesheet{} |> with_eom_soon()
    assert Checker.check_timesheet(ts).missing_eom_submit_soon

    ts = %Timesheet{} |> with_eom_soon() |> submitted()
    assert not Checker.check_timesheet(ts).missing_eom_submit_soon

    ts = %Timesheet{} |> with_eom()
    assert not Checker.check_timesheet(ts).missing_eom_submit_soon

    ts = %Timesheet{} |> with_wednesday()
    assert not Checker.check_timesheet(ts).missing_eom_submit_soon
  end

end
