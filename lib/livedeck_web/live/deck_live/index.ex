defmodule LivedeckWeb.DeckLive.Index do
  use LivedeckWeb, :live_view

  @impl
  def render(assigns) do
    ~H"""
    Hello world! <%= LivedeckWeb.Endpoint.url() %>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, stream(socket, :decks, list_decks())}
  end

  defp list_decks() do
    dbg(:code.priv_dir(:livedeck))
    []
  end
end
