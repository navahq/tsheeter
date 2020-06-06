defmodule TsheeterWeb.OauthController do
  alias Tsheeter.Oauther
  use TsheeterWeb, :controller
  require Logger

  def callback(conn, %{"code" => code, "state" => state}) do
    Oauther.callback(code, state)
    render(conn, "success.html")
  end

  def callback(conn, %{"error" => error, "error_description" => error_description}) do
    render(conn, "failure.html", error: error, error_description: error_description)
  end
end
