defmodule TsheeterWeb.OauthLive do
  use TsheeterWeb, :live_view
  alias Tsheeter.Oauther
  import Logger

  def mount(%{"code" => code, "state" => state}, _session, socket) do
    if connected?(socket) do
      id = Oauther.callback(code, state)
      Oauther.subscribe(id)
    end

    {:ok, assign(socket, success: true, msg: "Waiting for your task to start...", state: :working)}
  end

  def mount(%{"error" => error, "error_description" => error_description}, _session, socket) do
    {:ok, assign(socket, success: false, error: error, error_description: error_description)}
  end

  def handle_info(:getting_token, socket) do
    Logger.info "==> getting token"
    {:noreply, assign(socket, msg: "Reaching out to TSheets to get your authorization token...")}
  end

  def handle_info({:got_token, _token}, socket) do
    Logger.info "==> got token"
    {:noreply, assign(socket, state: :done)}
  end

  def handle_info({:error_getting_token, error}, socket) do
    Logger.error inspect(error)
    {:noreply, assign(socket, state: :error, error: error)}
  end
end
