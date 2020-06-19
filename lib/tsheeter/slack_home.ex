defmodule Tsheeter.SlackHome do
  use GenServer
  alias Tsheeter.UserManager
  alias Tsheeter.Token
  alias Tsheeter.Sync
  require Logger

  @server_name :slack_home

  ### Public API

  def start_link(_) do
    GenServer.start_link(__MODULE__, :initial_state, name: @server_name)
  end

  def init(_) do
    state = %{bot_token: System.get_env("SLACK_BOT_TOKEN")}
    Sync.subscribe()
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

  ### Message handlers

  def handle_cast({:set_connected, user_id, token}, %{bot_token: bot_token} = state) do
    handle_connected(user_id, token, bot_token)
    {:noreply, state}
  end

  def handle_cast({:set_disconnected, user_id}, %{bot_token: bot_token} = state) do
    handle_disconnected(user_id, bot_token)
    {:noreply, state}
  end

  def handle_cast({:disconnect_pressed, user_id}, state) do
    token = Token.get_by_slack_id(user_id)
    if token, do: Token.delete!(token)

    set_disconnected(user_id)
    {:noreply, state}
  end

  def handle_info({:token_available, %Tsheeter.Token{slack_uid: slack_uid} = token}, %{bot_token: bot_token} = state) do
    handle_connected(slack_uid, token, bot_token)
    {:noreply, state}
  end

  ### Private functions

  defp handle_connected(user_id, _token, bot_token) do
    request = %{
      type: :home,
      title: %{
        type: :plain_text,
        text: "TSheeter Home"
      },
      blocks: [
        intro_block(),
        %{
          type: :section,
          text: %{
            type: :mrkdwn,
            text: "Your slack profile is currently *connected* to TSheets."
          }
        },
        %{
          type: :actions,
          elements: [
            %{
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
          ]
        },
      ]
    }

    Slack.Web.Views.publish(bot_token, user_id, Jason.encode!(request))
    |> check_error(request)
  end

  defp handle_disconnected(user_id, bot_token) do
    {:ok, _pid} = UserManager.create(user_id)

    request = %{
      type: :home,
      title: %{
        type: :plain_text,
        text: "TSheeter Home"
      },
      blocks: [
        intro_block(),
        %{
          type: :section,
          text: %{
            type: :mrkdwn,
            text: "Your slack profile is currently *not connected* to TSheets, so you won't receive any notifications."
          }
        },
        %{
          type: :actions,
          elements: [
            %{
              type: :button,
              text: %{
                type: :plain_text,
                text: "Connect me!",
                emoji: true
              },
              url: UserManager.authorize_url(user_id),
              style: :primary
            }
          ]
        }
      ]
    }

    Slack.Web.Views.publish(bot_token, user_id, Jason.encode!(request))
    |> check_error(request)
  end

  defp intro_block() do
    %{
      type: :section,
      text: %{
      type: :mrkdwn,
      text: "TSheeter is a bot that can connect to your TSheets account and remind you each day if you forget to save your time."
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
