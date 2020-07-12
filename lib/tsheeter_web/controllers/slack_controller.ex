defmodule TsheeterWeb.SlackController do
  use TsheeterWeb, :controller
  alias Tsheeter.Token
  alias Tsheeter.SlackHome
  require Logger

  plug TsheeterWeb.VerifyTokenPlug

  def interact(
        %{
          assigns: %{
            payload: %{
              "user" => %{"id" => slack_uid},
              "actions" => [%{"type" => "button", "value" => "disconnect"}]
            }
          }
        } = conn,
        _params
      ) do
    SlackHome.disconnect_pressed(slack_uid)
    text(conn, "OK")
  end

  def interact(
    %{
      assigns: %{
        payload: %{
          "user" => %{"id" => slack_uid},
          "actions" => [%{"type" => "button", "value" => "change_check_time"}],
          "trigger_id" => trigger_id
        }
      }
    } = conn,
    _params
  ) do
    SlackHome.open_change_time_modal(slack_uid, trigger_id)
    text(conn, "OK")
  end

  def interact(
    %{
      assigns: %{
        payload: %{
          "user" => %{"id" => slack_uid},
          "trigger_id" => trigger_id,
          "view" => %{
            "callback_id" => "change_time_modal",
            "state" => %{"values" => %{"change_time_input" => %{"change_check_time" => %{"value" => value}}}}
          }
        }
      }
    } = conn,
    _params
  ) do
    case SlackHome.change_time(slack_uid, trigger_id, value) do
      :ok -> json(conn, %{response_action: :clear})
      :error ->
        json(conn, %{
          response_action: :update,
          view: SlackHome.change_time_modal_view(slack_uid, "*Unable to parse that time. Please enter something like \"2:15 PM\"*")
        })
    end
  end

  def interact(conn, _params), do: text(conn, "OK")

  def event(conn, %{
        "challenge" => challenge,
        "type" => "url_verification"
      }) do
    text(conn, challenge)
  end

  def event(conn, %{
        "event" => %{"type" => "app_home_opened", "tab" => "home", "user" => user_id}
      }) do
    case Token.get_by_slack_id(user_id) do
      nil ->
        SlackHome.set_disconnected(user_id)
      token ->
        SlackHome.set_connected(user_id, token)
    end

    text(conn, "OK")
  end

  def event(conn, _), do: text(conn, "OK")
end
