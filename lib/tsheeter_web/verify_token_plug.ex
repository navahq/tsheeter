defmodule TsheeterWeb.VerifyTokenPlug do
  import Plug.Conn
  require Logger

  def init(_) do
    Application.fetch_env!(:tsheeter, :slack_verify_token)
  end

  def call(conn = %{body_params: %{"token" => token}}, token), do: conn

  def call(conn = %{body_params: %{"payload" => payload}}, token) do
    case data = Jason.decode!(payload) do
      %{"token" => ^token} ->
        assign(conn, :payload, data)

      _ ->
        unverified(conn)
    end
  end

  def call(conn, _opts), do: unverified(conn)

  defp unverified(conn) do
    conn
    |> put_status(401)
    |> Phoenix.Controller.text("Unauthorized")
    |> halt()
  end

end
