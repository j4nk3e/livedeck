defmodule Livedeck.State do
  defstruct name: "", slide: 0, controller: false, viewers: %{}
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
  alias Phoenix.PubSub

  @initial_state %State{name: "", slide: 0, controller: false, viewers: %{}}

  def start_link(args) do
    opts = args |> Keyword.take([:name])
    GenServer.start_link(__MODULE__, args, opts)
  end

  def add(name, viewer) do
    Logger.info("Adding viewer #{viewer}")
    GenServer.call({:via, Registry, {Livedeck.Registry, name}}, {:add_viewer, viewer})
  end

  def page(name, page) do
    GenServer.call({:via, Registry, {Livedeck.Registry, name}}, {:page, page})
  end

  def log(name) do
    GenServer.call({:via, Registry, {Livedeck.Registry, name}}, :log_state)
  end

  @impl true
  def init(name: {:via, Registry, {Livedeck.Registry, name}}) do
    {:ok, %{@initial_state | name: name}}
  end

  @impl true
  def handle_call(:log_state, _from, state) do
    {:reply, "State: #{inspect(state)}", state}
  end

  @impl true
  def handle_call({:page, slide}, _from, state) do
    new_state = %{state | slide: slide}
    PubSub.broadcast(Livedeck.PubSub, new_state.name, new_state)
    {:reply, slide, new_state}
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
    PubSub.broadcast(Livedeck.PubSub, new_state.name, new_state)
    {:reply, new_state, new_state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, %State{viewers: viewers} = state) do
    # Use channels to broadcast updates https://hexdocs.pm/phoenix/channels.html#overview
    {v, map} = Map.pop(viewers, pid)
    new_state = %{state | viewers: map}
    Logger.info("Process for viewer #{v} disconnected")
    PubSub.broadcast(Livedeck.PubSub, new_state.name, new_state)
    {:noreply, new_state}
  end
end
