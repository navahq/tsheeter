defmodule TsheeterWeb.VerifyTokenPlug do
  import Plug.Conn
  require Logger

  def init(opts), do: opts

  def call(conn = %{body_params: %{"token" => token}}, _opts) do
    if token == fetch_token() do
      conn
    else
      unverified(conn)
    end
  end

  def call(conn = %{body_params: %{"payload" => payload}}, _opts) do
    token = fetch_token()
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

  defp fetch_token(), do: Application.fetch_env!(:tsheeter, :slack_verify_token)
end
