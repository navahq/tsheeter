defmodule Tsheeter.SlackHome do
  use GenServer
  alias Tsheeter.User
  alias Tsheeter.Token
  require Logger

  @server_name :slack_home
  @timezone "US/Eastern"

  ### Public API

  def start_link(_) do
    GenServer.start_link(__MODULE__, :initial_state, name: @server_name)
  end

  def init(_) do
    state = %{bot_token: System.get_env("SLACK_BOT_TOKEN")}
    Token.subscribe()
    {:ok, state}
  end

  def disconnect_pressed(user_id) do
    GenServer.cast(@server_name, {:disconnect_pressed, user_id})
  end

  def set_connected(user_id, token) do
    GenServer.cast(@server_name, {:set_connected, user_id, token})
  end

  def set_disconnected(user_id) do
    GenServer.cast(@server_name, {:set_disconnected, user_id})
  end

  def open_change_time_modal(user_id, trigger_id) do
    GenServer.cast(@server_name, {:open_change_time_modal, user_id, trigger_id})
  end

  def change_time(user_id, trigger_id, new_time) do
    case parse_time(new_time) do
      %Time{} = t ->
        GenServer.cast(@server_name, {:change_time, user_id, trigger_id, t})
        :ok
      x -> x
    end
  end

  def parse_time(time_str) do
    regex = ~r/(\d+):(\d+)\s*(AM|PM)/i

    case Regex.run(regex, time_str) do
      nil -> nil
      [_, h, m, ampm] ->
        h = String.to_integer(h)
        m = String.to_integer(m)
        offset = if String.downcase(ampm) == "pm", do: 12, else: 0
        case Time.new(h + offset, m, 0) do
          {:ok, t} -> t
          {:error, _} -> :error
        end
    end
  end

  ### Message handlers

  def handle_cast({:open_change_time_modal, user_id, trigger_id}, %{bot_token: bot_token} = state) do
    handle_open_change_time_modal(user_id, trigger_id, bot_token)
    {:noreply, state}
  end

  def handle_cast({:set_connected, user_id, token}, %{bot_token: bot_token} = state) do
    handle_connected(user_id, token, bot_token)
    {:noreply, state}
  end

  def handle_cast({:set_disconnected, user_id}, %{bot_token: bot_token} = state) do
    handle_disconnected(user_id, bot_token)
    {:noreply, state}
  end

  def handle_cast({:disconnect_pressed, user_id}, state) do
    User.forget_token(user_id)

    set_disconnected(user_id)
    {:noreply, state}
  end

  def handle_cast({:change_time, user_id, _trigger_id, %Time{hour: hour, minute: minute}}, %{bot_token: bot_token} = state) do
    Token.set_check_time(user_id, Token.to_time(hour, minute, @timezone))
    token = Token.get_by_slack_id(user_id)
    handle_connected(user_id, token, bot_token)

    {:noreply, state}
  end

  def handle_info({:token, %Token{slack_uid: slack_uid} = token}, %{bot_token: bot_token} = state) do
    handle_connected(slack_uid, token, bot_token)
    {:noreply, state}
  end

  def handle_info(_, state), do: {:noreply, state}

  ### Private functions

  defp handle_connected(user_id, %Token{check_time: time}, bot_token) do
    local_time =
      Token.to_timezone(time, @timezone)
      |> Calendar.Strftime.strftime!("%I:%M %p")

    request = %{
      type: :home,
      title: %{
        type: :plain_text,
        text: "TSheeter Home"
      },
      blocks: [
        intro_block(),
        %{type: :divider},
        %{
          type: :section,
          text: %{
            type: :mrkdwn,
            text: ":alarm_clock: I'm currently checking your timesheet on weekdays at *#{local_time} #{@timezone}*."
          },
          accessory: %{
            type: :button,
            text: %{
              type: :plain_text,
              text: "Change time",
              emoji: true
            },
            value: :change_check_time,
          }
        },
        %{
          type: :section,
          text: %{
            type: :mrkdwn,
            text: ":heart: Your slack profile is currently *connected* to TSheets."
          },
          accessory: %{
            type: :button,
            text: %{
              type: :plain_text,
              text: "Disconnect me!",
              emoji: true
            },
            value: :disconnect,
            style: :danger,
            confirm: %{
              title: %{
                type: :plain_text,
                text: "Are you sure?"
              },
              text: %{
                type: :mrkdwn,
                text: "This will stop all reminders and delete all your information from storage."
              },
              confirm: %{
                type: :plain_text,
                text: "Disconnect me"
              },
              deny: %{
                type: :plain_text,
                text: "Cancel"
              }
            }
          }
        }
      ]
    }

    Slack.Web.Views.publish(bot_token, user_id, Jason.encode!(request))
    |> check_error(request)
  end

  defp handle_disconnected(user_id, bot_token) do
    {:ok, _pid} = User.create(user_id)

    request = %{
      type: :home,
      title: %{
        type: :plain_text,
        text: "TSheeter Home"
      },
      blocks: [
        intro_block(),
        %{type: :divider},
        %{
          type: :section,
          text: %{
            type: :mrkdwn,
            text: ":broken_heart: Your slack profile is currently *not connected* to TSheets, so you won't receive any notifications."
          },
          accessory: %{
              type: :button,
              text: %{
                type: :plain_text,
                text: "Connect me!",
                emoji: true
              },
              url: User.authorize_url(user_id),
              style: :primary
          }
        }
      ]
    }

    Slack.Web.Views.publish(bot_token, user_id, Jason.encode!(request))
    |> check_error(request)
  end

  def change_time_modal_view(user_id, error \\ nil) do
    %Token{check_time: time} = Token.get_by_slack_id(user_id)
    local_time = Token.to_timezone(time, @timezone)
    local_time_str = Calendar.Strftime.strftime!(local_time,"%I:%M %p")

    intro_block =
      %{
        type: :section,
        text: %{
          type: "mrkdwn",
          text: "I'm currently checking your timesheets on weekdays at #{local_time_str} #{@timezone}."
        }
      }

    input_block =
      %{
        type: :input,
        block_id: :change_time_input,
        label: %{
          type: :plain_text,
          text: "New time (in #{@timezone}):"
        },
        element: %{
          type: :plain_text_input,
          action_id: :change_check_time,
          initial_value: local_time_str
        }
      }

    blocks = [intro_block, input_block]
    blocks = blocks ++ if error, do: [%{type: :section, text: %{type: "mrkdwn", text: error}}], else: []

    %{
      type: :modal,
      callback_id: :change_time_modal,
      title: %{
        type: :plain_text,
        text: "Change Daily Check Time",
      },
      submit: %{
        type: :plain_text,
        text: "Submit",
        emoji: true
      },
      blocks: blocks
    }
  end

  def handle_open_change_time_modal(user_id, trigger_id, bot_token) do
    request = change_time_modal_view(user_id)
    Slack.Web.Views.open(bot_token, trigger_id, Jason.encode!(request))
    |> check_error(request)
  end

  defp intro_block() do
    %{
      type: :section,
      text: %{
        type: :mrkdwn,
        text: """
        *Beep boop!* I'm a bot that can connect to your TSheets account and remind you each day if you forget to save or submit your time. I use these rules:

        1. Every weekday should have time logged.
        2. Time should be submited on the last work day of each month.
        3. Time should also be submitted every Friday.

        """
      }
    }
  end

  defp check_error(%{"ok" => true} = resp, _req), do: resp
  defp check_error(%{"ok" => false} = resp, req) do
    req = Jason.encode!(req, pretty: true)
    resp = Jason.encode!(resp, pretty: true)
    Logger.info("[request] #{req}")
    Logger.error("[response] #{resp}")
  end
end
