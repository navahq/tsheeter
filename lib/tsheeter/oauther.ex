defmodule Tsheeter.Oauther do
  use GenServer
  require Logger

  defmodule State do
    defstruct [
      :id,            # this session's identifier to the outside world
      :state_token,   # random string used to verify sender during OAuth2 callback
      :client         # oauth2 client
    ]
  end

  ### Client API

  def create(id) do
    Horde.DynamicSupervisor.start_child(Tsheeter.UserSupervisor, {__MODULE__, id})
  end

  def start_link(id) do
    client =
      OAuth2.Client.new(Application.fetch_env!(:tsheeter, :oauth))
      |> OAuth2.Client.put_serializer("application/json", Jason)

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
  end

  defp token_info(%OAuth2.AccessToken{access_token: access_token, expires_at: expires_at, refresh_token: refresh_token, other_params: %{"user_id" => user_id}}) do
    %{
      access_token: access_token,
      expires_at: expires_at,
      refresh_token: refresh_token,
      user_id: user_id
    }
  end

  ### Server callbacks

  def handle_call({:get_state}, _from, state) do
    {:reply, state, state}
  end

  def handle_call({:authorize_url}, _from, %State{id: id, client: client, state_token: state_token} = state) do
    oauth_state = Base.encode64("#{id}:#{state_token}")
    url = OAuth2.Client.authorize_url!(client, state: oauth_state)
    {:reply, url, state}
  end

  def handle_cast({:auth_code, code, received_token}, %State{state_token: received_token, client: client} = state) do
    broadcast(state, :getting_token)

    case OAuth2.Client.get_token(client, code: code) do
      {:ok, client} ->
        broadcast(state, {:got_token, token_info(client.token)})
        {:noreply, %{state | client: client}}
      {:error, result} ->
        Logger.error inspect(result)
        broadcast(state, {:error_getting_token, result})
        {:noreply, state}
    end
  end
end
