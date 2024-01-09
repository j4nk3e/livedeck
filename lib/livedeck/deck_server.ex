defmodule Livedeck.State do
  defstruct page: 0, controller: false, viewers: %{}
end

defmodule Livedeck.DynamicSupervisor do
  use DynamicSupervisor

  def start_link(args), do: DynamicSupervisor.start_link(__MODULE__, args, name: __MODULE__)
  def init(_), do: DynamicSupervisor.init(strategy: :one_for_one)

  def add_child(name) when name |> is_binary do
    pid = child_process(name)
    spec = Livedeck.Server.child_spec(name: pid)
    DynamicSupervisor.start_child(__MODULE__, spec)
  end

  def remove_child(name) when name |> is_binary do
    [{pid, _}] = Registry.lookup(Livedeck.Registry, name)
    :ok = DynamicSupervisor.terminate_child(__MODULE__, pid)
    Registry.unregister(Livedeck.Registry, name)
  end

  def child_process(name), do: {:via, Registry, {Livedeck.Registry, name}}
end

defmodule Livedeck.Server do
  use GenServer
  require Logger
  alias Livedeck.State

  @initial_state %State{page: 0, controller: false, viewers: %{}}

  def start_link(args) do
    opts = args |> Keyword.take([:name])
    GenServer.start_link(__MODULE__, args, opts)
  end

  def add(name, viewer) do
    Logger.info("Adding viewer #{viewer}")
    GenServer.call({:via, Registry, {Livedeck.Registry, name}}, {:add_viewer, viewer})
  end

  def get(name) do
    GenServer.call({:via, Registry, {Livedeck.Registry, name}}, :get_count)
  end

  def log(name) do
    GenServer.call({:via, Registry, {Livedeck.Registry, name}}, :log_state)
  end

  @impl true
  def init(_args) do
    {:ok, @initial_state}
  end

  @impl true
  def handle_call(:log_state, _from, state) do
    {:reply, "State: #{inspect(state)}", state}
  end

  @impl true
  def handle_call(:get_count, _from, %State{viewers: viewers} = state) do
    {:reply, map_size(viewers), state}
  end

  @impl true
  def handle_call({:add_viewer, viewer}, {from, _}, %State{viewers: viewers} = state) do
    # https://github.com/phoenixframework/phoenix_live_view/issues/123#issuecomment-475926480
    Process.monitor(from)
    new_state = %{state | viewers: Map.put(viewers, from, viewer)}
    {:reply, :viewer_added, new_state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, %State{viewers: viewers} = state) do
    # Use channels to broadcast updates https://hexdocs.pm/phoenix/channels.html#overview
    {v, map} = Map.pop(viewers, pid)
    new_state = %{state | viewers: map}
    Logger.info("Process for viewer #{v} disconnected")
    {:noreply, new_state}
  end
end
