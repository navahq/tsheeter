defmodule Tsheeter.User do
  alias Tsheeter.Token
  alias OAuth2.Client
  alias OAuth2.AccessToken
  use GenServer
  require Logger

  defmodule State do
    defstruct [
      :id,            # this session's identifier to the outside world
      :tsheets_uid,   # tsheets user ID
      :state_token,   # random string used to verify sender during OAuth2 callback
      :client,        # oauth2 client
      :slack_token    # slack bot token
    ]
  end

  defmodule Timesheet do
    defstruct [
      :date,
      saved_hours: 0.0,
      submitted?: false
    ]
  end

  @timezone "US/Eastern"
  @renew_secs_before_expiration 60 * 60 * 12    # renew tokens 12 hours before they expire
  @refresh_error_retry_secs 60 * 30             # retry failed refreshes 30 minutes later

  ### Client API

  def create(%Token{slack_uid: slack_uid} = token) do
    create(slack_uid, token)
  end

  def create(id, token \\ nil) do
    case Horde.DynamicSupervisor.start_child(Tsheeter.Supervisor, {__MODULE__, %{id: id, token: token}}) do
      {:ok, _} = response -> response
      {:error, {{:badmatch, {:error, {:already_started, pid}}}, _}} ->
        {:ok, pid}
      {:error, {:already_started, pid}} ->
        {:ok, pid}
      x -> x
    end
  end

  def start_link(%{id: id, token: token}) do
    client =
      Client.new(Application.fetch_env!(:tsheeter, :oauth))
      |> Client.put_serializer("application/json", Jason)

    state = %State{
      id: id,
      state_token: state_token(id),
      client: client,
      slack_token: Application.fetch_env!(:tsheeter, :slack_bot_token)
    }
    |> apply_token(token)

    GenServer.start_link(__MODULE__, state, name: via_registry(id))
  end

  def init(%State{} = state) do
    Token.subscribe()
    {:ok, schedule_refresh!(state)}
  end

  def client(id) do
    GenServer.call(via_registry(id), {:get_client})
  end

  def authorize_url(id) do
    GenServer.call(via_registry(id), {:authorize_url})
  end

  def todays_timesheet(id) do
    GenServer.call(via_registry(id), {:todays_timesheet})
  end

  def encode_oauth_state(id, state_token), do: Base.encode64("#{id}:#{state_token}")

  def decode_oauth_state!(state) do
    [id, state_token] =
      state
      |> Base.decode64!
      |> String.split(":")
    {id, state_token}
  end

  def got_auth_code(code, oauth_state) do
    {id, state_token} = decode_oauth_state!(oauth_state)
    GenServer.cast(via_registry(id), {:got_auth_code, code, state_token})
    id
  end

  def refresh_token(id) do
    GenServer.cast(via_registry(id), :refresh_token)
  end

  def forget_token(id) do
    GenServer.cast(via_registry(id), :forget_token)
  end

  def send_message(id, msg) do
    GenServer.cast(via_registry(id), {:message, msg})
  end

  ### Private functions

  defp process_id(%State{id: id}), do: process_id(id)
  defp process_id(id), do: :"user_#{id}"

  defp via_registry(id) do
    {:via, Horde.Registry, {Tsheeter.Registry, process_id(id)}}
  end

  defp lookup(id) do
    case Horde.Registry.lookup(Tsheeter.Registry, process_id(id)) do
      [{pid, _}] -> pid
      _ -> nil
    end
  end

  defp state_token(id), do: :crypto.hash(:sha256, id) |> Base.url_encode64()

  defp apply_token(%State{} = state, nil), do: state

  defp apply_token(%State{client: client} = state, %Token{access_token: access_token, refresh_token: refresh_token, expires_at: expires_at, tsheets_uid: tsheets_uid}) do
    new_token =
      AccessToken.new(access_token)
      |> Map.put(:refresh_token, refresh_token)
      |> Map.put(:expires_at, DateTime.to_unix(expires_at))
      |> Map.put(:token_type, "Bearer")

    %{state | client: %{client | token: new_token}, tsheets_uid: tsheets_uid}
  end

  defp schedule_refresh!(state), do: schedule_refresh!(state, 0)

  defp schedule_refresh!(%State{id: id, client: %Client{token: %AccessToken{access_token: access_token, expires_at: expires_at}}} = state, minimum_renew) do
    seconds = DateTime.diff(DateTime.from_unix!(expires_at), DateTime.utc_now)

    if seconds < 0 do
      forget_token(id)
    else
      renew_in = max(seconds - @renew_secs_before_expiration, minimum_renew)
      Process.send_after(lookup(id), {:scheduled_refresh, access_token}, renew_in * 1000)
    end

    state
  end

  defp schedule_refresh!(state, _), do: state

  defp parse_date_str(nil), do: nil
  defp parse_date_str(s) when is_binary(s), do: Date.from_iso8601!(s)

  defp handle_token_result!(get_token_result, action, id) do
    case get_token_result do
      {:ok, client} ->
        Token.store_from_oauth!(id, client.token)
      {:error, result} ->
        Token.error!(id, action, result)
    end
  end

  ### Server callbacks

  def handle_call({:get_client}, _from, state) do
    {:reply, state.client, state}
  end

  def handle_call({:authorize_url}, _from, %State{id: id, client: client, state_token: state_token} = state) do
    oauth_state = Base.encode64("#{id}:#{state_token}")
    url = Client.authorize_url!(client, state: oauth_state)
    {:reply, url, state}
  end

  def handle_call({:todays_timesheet}, _from, %{client: client, tsheets_uid: tsheets_uid} = state) do
    today =
      DateTime.utc_now()
      |> DateTime.shift_zone!(@timezone)
      |> DateTime.to_date

    params = [page: 1, user_ids: tsheets_uid, start_date: today, end_date: today]
    response = Client.get!(client, "/api/v1/timesheets", [], params: params)

    submitted_to =
      response.body
      |> get_in(["supplemental_data", "users", to_string(tsheets_uid), "submitted_to"])
      |> parse_date_str()

    total_time =
      response.body
      |> get_in(["results", "timesheets"])
      |> Enum.map(fn {_k, v} -> Map.get(v, "duration") end)
      |> Enum.sum()

    result = %Timesheet{
      date: today,
      saved_hours: total_time / (60 * 60),
      submitted?: submitted_to >= today
    }

    {:reply, result, state}
  end

  def handle_cast({:got_auth_code, code, state_token}, %State{id: id, state_token: state_token, client: client} = state) do
    Client.get_token(client, code: code, client_secret: client.client_secret)
    |> handle_token_result!(:getting, id)

    {:noreply, state}
  end

  def handle_cast(:refresh_token, %State{id: id, client: client} = state) do
    Logger.info "Refreshing token for #{id}"

    Client.refresh_token(client,
      [client_id: client.client_id, client_secret: client.client_secret],
      [{"Authorization", "Bearer " <> client.token.access_token}])
    |> handle_token_result!(:refreshing, id)

    {:noreply, state}
  end

  def handle_cast(:forget_token, %State{id: id} = state) do
    token = Token.get_by_slack_id(id)
    if token, do: Token.delete!(token)

    {:noreply, %{state | client: %{state.client | token: nil}}}
  end

  def handle_cast({:message, msg}, %State{id: id, slack_token: slack_token} = state) do
    Slack.Web.Chat.post_message(id, msg, %{token: slack_token})
    |> check_error()

    {:noreply, state}
  end

  def handle_info({:token, %Token{slack_uid: id} = token}, %State{id: id} = state) do
    state =
      state
      |> apply_token(token)
      |> schedule_refresh!()

    {:noreply, state}
  end

  def handle_info({:error, %{slack_uid: id, action: :refreshing}}, %State{id: id} = state) do
    state = schedule_refresh!(state, @refresh_error_retry_secs)
    {:noreply, state}
  end

  def handle_info({:scheduled_refresh, access_token}, %State{client: %Client{token: %AccessToken{access_token: access_token}}} = state) do
    handle_cast(:refresh_token, state)
  end

  def handle_info({:scheduled_refresh, _}, %State{id: id} = state) do
    Logger.warn("id=#{id} Ignoring :scheduled_refresh for obsolete token")
    {:noreply, state}
  end

  def handle_info(_msg, state), do: {:noreply, state}

  defp check_error(%{"ok" => true} = resp), do: resp
  defp check_error(%{"ok" => false} = resp) do
    resp = Jason.encode!(resp, pretty: true)
    Logger.error("[response] #{resp}")
  end
end
