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
    if Token.get_by_slack_id(user_id) == nil do
      SlackHome.set_disconnected(user_id)
    end

    text(conn, "OK")
  end

  def event(conn, _), do: text(conn, "OK")
end
