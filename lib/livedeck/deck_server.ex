defmodule DeckState do
  defstruct page: 0, controller: false, viewers: %{}
end

defmodule Livedeck.DeckServer do
  use GenServer, restart: :permanent
  require Logger

  @initial_state %DeckState{page: 0, controller: false, viewers: %{}}

  def start_or_get(name) do
    case GenServer.start_link(__MODULE__, name, name: {:via, Registry, {:deck_registry, name}}) do
      {:error, {:already_started, pid}} -> pid
      {:ok, pid} -> pid
    end
  end

  def add(pid, viewer) do
    Logger.info("Adding viewer #{viewer}")
    GenServer.call(pid, {:add_viewer, viewer})
  end

  def get(pid) do
    GenServer.call(pid, :get_count)
  end

  def log(pid) do
    GenServer.call(pid, :log_state)
  end

  @impl true
  def init(name) do
    Logger.info("Starting process #{name}")
    {:ok, @initial_state}
  end

  @impl true
  def handle_call(:log_state, _from, state) do
    {:reply, "State: #{inspect(state)}", state}
  end

  @impl true
  def handle_call(:get_count, _from, %DeckState{viewers: viewers} = state) do
    {:reply, map_size(viewers), state}
  end

  @impl true
  def handle_call({:add_viewer, viewer}, {from, _}, %DeckState{viewers: viewers} = state) do
    # https://github.com/phoenixframework/phoenix_live_view/issues/123#issuecomment-475926480
    Process.monitor(from)
    new_state = %{state | viewers: Map.put(viewers, from, viewer)}
    {:reply, :viewer_added, new_state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, %DeckState{viewers: viewers} = state) do
    # Use channels to broadcast updates https://hexdocs.pm/phoenix/channels.html#overview
    {v, map} = Map.pop(viewers, pid)
    new_state = %{state | viewers: map}
    Logger.info("Process for viewer #{v} disconnected")
    {:noreply, new_state}
  end
end
