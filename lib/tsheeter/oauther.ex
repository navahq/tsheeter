defmodule Tsheeter.Oauther do
  alias Tsheeter.Token
  use GenServer, restart: :transient
  require Logger

  defmodule State do
    defstruct [
      :id,            # this session's identifier to the outside world
      :state_token,   # random string used to verify sender during OAuth2 callback
      :client         # oauth2 client
    ]
  end

  ### Client API

  def create(%Token{slack_uid: slack_uid} = token) do
    create(slack_uid, token)
  end

  def create(id, token \\ nil) do
    case Horde.DynamicSupervisor.start_child(Tsheeter.UserSupervisor, {__MODULE__, %{id: id, token: token}}) do
      {:ok, _} = response -> response
      {:error, {{:badmatch, {:error, {:already_started, pid}}}, _}} ->
        {:ok, pid}
      x -> x
    end
  end

  def start_link(%{id: id, token: token}) do
    client =
      OAuth2.Client.new(Application.fetch_env!(:tsheeter, :oauth))
      |> OAuth2.Client.put_serializer("application/json", Jason)
      |> apply_token(token)

    state = %State{
      id: id,
      state_token: random_string(16),
      client: client
    }

    {:ok, _pid} = GenServer.start_link(__MODULE__, state, name: via_registry(id))
  end

  def init(%State{} = state) do
    {:ok, state}
  end

  def state(id) do
    GenServer.call(via_registry(id), {:get_state})
  end

  def client(id) do
    GenServer.call(via_registry(id), {:get_client})
  end

  def authorize_url(id) do
    GenServer.call(via_registry(id), {:authorize_url})
  end

  def encode_oauth_state(id, state_token), do: Base.encode64("#{id}:#{state_token}")

  def decode_oauth_state!(state) do
    [id, state_token] =
      state
      |> Base.decode64!
      |> String.split(":")
    {id, state_token}
  end

  def callback(code, oauth_state) do
    {id, state_token} = decode_oauth_state!(oauth_state)
    GenServer.cast(via_registry(id), {:auth_code, code, state_token})
    id
  end

  def subscribe(id) do
    Phoenix.PubSub.subscribe(Tsheeter.PubSub, "oauth:#{id}")
  end

  def subscribe() do
    Phoenix.PubSub.subscribe(Tsheeter.PubSub, "oauth:*")
  end

  def refresh(id, access_token, refresh_token) do
    GenServer.cast(via_registry(id), {:refresh, access_token, refresh_token})
  end

  ### Private functions

  defp process_id(%State{id: id}), do: process_id(id)
  defp process_id(id), do: :"oauther_#{id}"

  defp via_registry(id) do
    {:via, Horde.Registry, {Tsheeter.Registry, process_id(id)}}
  end

  defp random_string(length) do
    :crypto.strong_rand_bytes(length)
    |> Base.url_encode64
    |> binary_part(0, length)
  end

  defp broadcast(%{id: id}, data) do
    Phoenix.PubSub.broadcast(Tsheeter.PubSub, "oauth:#{id}", data)
    Phoenix.PubSub.broadcast(Tsheeter.PubSub, "oauth:*", data)
  end

  defp token_info(%OAuth2.AccessToken{access_token: access_token, expires_at: expires_at, refresh_token: refresh_token, other_params: %{"user_id" => user_id}}) do
    %{
      access_token: access_token,
      expires_at: expires_at,
      refresh_token: refresh_token,
      user_id: user_id
    }
  end

  defp apply_token(client, nil), do: client

  defp apply_token(client, %Token{access_token: access_token, refresh_token: refresh_token, expires_at: expires_at}) do
    token =
      OAuth2.AccessToken.new(access_token)
      |> Map.put(:refresh_token, refresh_token)
      |> Map.put(:expires_at, DateTime.to_unix(expires_at))
      |> Map.put(:token_type, "Bearer")

    %{client | token: token}
  end

  ### Server callbacks

  def handle_call({:get_state}, _from, state) do
    {:reply, state, state}
  end

  def handle_call({:get_client}, _from, state) do
    {:reply, state.client, state}
  end

  def handle_call({:authorize_url}, _from, %State{id: id, client: client, state_token: state_token} = state) do
    oauth_state = Base.encode64("#{id}:#{state_token}")
    url = OAuth2.Client.authorize_url!(client, state: oauth_state)
    {:reply, url, state}
  end

  def handle_cast({:auth_code, code, received_token}, %State{id: id, state_token: received_token, client: client} = state) do
    broadcast(state, :getting_token)

    case OAuth2.Client.get_token(client, code: code) do
      {:ok, client} ->
        broadcast(state, {:got_token, id, token_info(client.token)})
        {:stop, :normal, %{state | client: client}}
      {:error, result} ->
        Logger.error inspect(result)
        broadcast(state, {:error_getting_token, result})
        {:stop, :normal, state}
    end
  end

  def handle_cast({:refresh, access_token, refresh_token}, %State{id: id} = state) do
    Logger.info "Refreshing token for #{id}"

    token =
      OAuth2.AccessToken.new(access_token)
      |> Map.put(:refresh_token, refresh_token)
      |> Map.put(:token_type, "Bearer")

    config =
      Application.fetch_env!(:tsheeter, :oauth)
      |> Keyword.put(:token, token)

    client =
      OAuth2.Client.new(config)
      |> OAuth2.Client.put_serializer("application/json", Jason)

    {:ok, client} =
      OAuth2.Client.refresh_token(client,
        [client_id: client.client_id, client_secret: client.client_secret],
        [{"Authorization", "Bearer " <> access_token}])

    broadcast(state, {:got_token, id, token_info(client.token)})
    {:stop, :normal, %{state | client: client}}
  end
end
