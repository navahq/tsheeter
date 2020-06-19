defmodule TsheeterWeb.OauthLive do
  use TsheeterWeb, :live_view
  alias Tsheeter.Token
  alias Tsheeter.UserManager

  def mount(%{"code" => code, "state" => state}, _session, socket) do
    socket = assign(socket, success: true, msg: "Reaching out to TSheets to get your authorization token...", state: :working)

    if connected?(socket) do
      id = UserManager.got_auth_code(code, state)
      Token.subscribe()
      {:ok, assign(socket, id: id)}
    else
      {:ok, socket}
    end
  end

  def mount(%{"error" => error, "error_description" => error_description}, _session, socket) do
    {:ok, assign(socket, success: false, error: error, error_description: error_description)}
  end

  def handle_info({:token, _token}, socket) do
    {:noreply, assign(socket, state: :done)}
  end

  def handle_info(
    {:error, %{slack_uid: slack_uid, result: result}},
    socket = %{assigns: %{id: slack_uid}}
    ) do
    {:noreply, assign(socket, state: :error, error: result)}
  end
end
