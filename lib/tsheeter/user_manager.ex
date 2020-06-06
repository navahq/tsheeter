defmodule Tsheeter.UserManager do
  use GenServer
  require Logger

  ### Client API

  def create(slack_id) do
    Horde.DynamicSupervisor.start_child(Tsheeter.UserSupervisor, {__MODULE__, slack_id})
  end

  def child_spec(slack_id) do
    %{id: process_id(slack_id), start: {__MODULE__, :start_link, [slack_id]}}
  end

  def start_link(slack_id) do
    state = %{slack_id: slack_id, greetings: 0}
    {:ok, _pid} = GenServer.start_link(__MODULE__, state, name: via_registry(slack_id))
  end

  def init(%{slack_id: slack_id} = state) do
    Logger.warn("==> User #{slack_id} running on #{inspect(Node.self())}")
    Logger.debug(inspect(state, pretty: true))
    {:ok, state}
  end

  def process_id(slack_id), do: :"user_#{slack_id}"

  def hello(slack_id, who) do
    GenServer.cast(via_registry(slack_id), {:hello, who})
  end

  ### Private functions

  defp via_registry(slack_id) do
    {:via, Horde.Registry, {Tsheeter.Registry, process_id(slack_id)}}
  end

  ### Server callbacks

  def handle_cast({:hello, who}, %{slack_id: slack_id, greetings: greetings} = state) do
    Logger.info "Hello to #{who} from #{slack_id}"
    {:noreply, %{state | greetings: greetings + 1}}
  end
end
