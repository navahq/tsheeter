defmodule TsheeterWeb.SlackController do
  use TsheeterWeb, :controller
  alias Tsheeter.Token
  alias Tsheeter.SlackHome
  require Logger

  @verify_token System.get_env("SLACK_VERIFICATION_TOKEN")

  plug :verify_token when action in [:event, :interact]

  defp verify_token(conn = %{body_params: %{"token" => @verify_token}}, _opts), do: conn
  defp verify_token(conn = %{body_params: %{"payload" => payload}}, _opts) do
    case data = Jason.decode!(payload) do
      %{"token" => @verify_token} ->
        assign(conn, :payload, data)
      _ ->
        unverified(conn)
    end
  end

  defp verify_token(conn, _opts), do: unverified(conn)

  def unverified(conn), do: conn |> put_status(401) |> text("Unauthorized") |> halt()

  def interact(conn, _params) do
    payload = conn.assigns[:payload]  # set by :verify_token plug

    case payload do
      %{"user" => %{"id" => slack_uid}, "actions" => [%{"type" => "button", "value" => "disconnect"}]} ->
        SlackHome.disconnect_pressed(slack_uid)
      _ ->
        Logger.info "Ignoring interaction"
    end

    text(conn, "OK")
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
    if Token.get_by_slack_id(user_id) == nil do
      SlackHome.set_disconnected(user_id)
    end

    text(conn, "OK")
  end

  def event(conn, %{"token" => @verify_token}), do: text(conn, "OK")
end
