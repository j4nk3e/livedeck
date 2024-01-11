defmodule Livedeck.State do
  defstruct name: "", slide: 0, controller: false
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

  @initial_state %State{name: "", slide: 0, controller: false}

  def start_link(args) do
    opts = args |> Keyword.take([:name])
    GenServer.start_link(__MODULE__, args, opts)
  end

  def page(name, page) do
    GenServer.call({:via, Registry, {Livedeck.Registry, name}}, {:page, page})
  end

  @impl true
  def init(name: {:via, Registry, {Livedeck.Registry, name}}) do
    {:ok, %{@initial_state | name: name}}
  end

  @impl true
  def handle_call({:page, page}, _from, state) do
    new_state = %{state | slide: state.slide + page}
    PubSub.broadcast(Livedeck.PubSub, new_state.name, new_state)
    {:reply, new_state.slide, new_state}
  end
end
