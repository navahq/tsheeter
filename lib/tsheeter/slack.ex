defmodule Tsheeter.Slack do
  @moduledoc """
  The main connection between the bot and slack.
  """
  use Slack

  def handle_connect(slack, state) do
    dbg = inspect(state)
    IO.puts(dbg)
    IO.puts("Connected as #{slack.me.name}")

    # token = System.get_env("SLACK_API_TOKEN")

    # slack
    # |> Map.put(:bots, Slack.Web.Bots.info(%{token: token}) |> Map.get("bot"))
    # |> Map.put(:channels, Slack.Web.Channels.list(%{token: token}) |> Map.get("channels"))
    # |> Map.put(:groups, Slack.Web.Groups.list(%{token: token}) |> Map.get("groups"))
    # |> Map.put(:ims, Slack.Web.Im.list(%{token: token}) |> Map.get("ims"))
    # |> Map.put(:users, Slack.Web.Users.list(%{token: token}) |> Map.get("members"))

    {:ok, state}
  end

  def handle_event(
        message = %{type: "message"},
        _slack = %{token: _token, me: %{id: me_id}},
        state
      ) do
    IO.puts(inspect(message, pretty: true))
    IO.puts("My id: #{me_id}")
    {:ok, state}
  end

  def handle_event(_, _, state), do: {:ok, state}

  def handle_info({:message, text, channel}, slack, state) do
    IO.puts("Sending a message")
    send_message(text, channel, slack)
    {:ok, state}
  end

  def handle_info(_, _, state), do: {:ok, state}
end
