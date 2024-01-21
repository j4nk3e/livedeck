defmodule Livedeck.State do
  defstruct name: "", slide: 0, pages: 0
end

defmodule Livedeck.DynamicSupervisor do
  use DynamicSupervisor

  def start_link(args), do: DynamicSupervisor.start_link(__MODULE__, args, name: __MODULE__)
  def init(_), do: DynamicSupervisor.init(strategy: :one_for_one)

  def add_child({name, pages}) when name |> is_binary do
    pid = child_process(name)
    spec = Livedeck.Server.child_spec(name: pid, pages: pages)
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

  def start_link(args) do
    opts = args |> Keyword.take([:name])
    GenServer.start_link(__MODULE__, args, opts)
  end

  def set_page(name, page) do
    GenServer.call({:via, Registry, {Livedeck.Registry, name}}, {:page, page})
  end

  def get_page(name) do
    GenServer.call({:via, Registry, {Livedeck.Registry, name}}, :get_page)
  end

  @impl true
  def init(name: {:via, Registry, {Livedeck.Registry, name}}, pages: pages) do
    {:ok, %{%State{} | name: name, pages: pages}}
  end

  @impl true
  def handle_call({:page, page}, _from, state) do
    new_state = %{state | slide: min(state.pages - 1, max(0, page))}
    PubSub.broadcast(Livedeck.PubSub, new_state.name, new_state)
    {:reply, new_state.slide, new_state}
  end

  @impl true
  def handle_call(:get_page, _from, state) do
    {:reply, state.slide, state}
  end
end
