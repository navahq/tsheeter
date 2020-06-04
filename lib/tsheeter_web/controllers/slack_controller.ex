defmodule TsheeterWeb.SlackController do
  use TsheeterWeb, :controller
  require Logger

  @verify_token System.get_env("SLACK_VERIFICATION_TOKEN")
  @bot_token System.get_env("SLACK_BOT_TOKEN")

  def interact(conn, _params = %{"payload" => %{"callback_id" => "configure"}}) do
    json(conn, %{text: "Hello world!", response_type: "ephemeral"})
  end

  def event(conn, %{
        "token" => @verify_token,
        "challenge" => challenge,
        "type" => "url_verification"
      }) do
    text(conn, challenge)
  end

  def event(conn, %{
        "token" => @verify_token,
        "event" => %{"type" => "app_home_opened", "tab" => "home", "user" => user_id}
      }) do
    request = %{
      type: :home,
      title: %{
        type: :plain_text,
        text: "TSheeter Home"
      },
      blocks: [
        %{
          type: :section,
          text: %{
            type: :mrkdwn,
            text: "Hello world!"
          }
        }
      ]
    }

    Slack.Web.Views.publish(@bot_token, user_id, Jason.encode!(request))
    |> check_error(request)

    text(conn, "OK")
  end

  defp check_error(%{"ok" => true} = resp, _req), do: resp

  defp check_error(%{"ok" => false} = resp, req) do
    req = Jason.encode!(req, pretty: true)
    resp = Jason.encode!(resp, pretty: true)
    Logger.info("[request] #{req}")
    Logger.error("[response] #{resp}")
  end

  def event(conn, %{"token" => @verify_token}) do
    text(conn, "OK")
  end
end
