defmodule LivedeckWeb.DeckLive.Index do
  alias Livedeck.Presence
  use LivedeckWeb, :live_view
  alias QRCode.Render.SvgSettings
  alias Phoenix.PubSub
  require Logger

  @themes ["forest", "dark", "synthwave"]

  defp qr(s) do
    svg_settings = %SvgSettings{background_opacity: 0, scale: 20, qrcode_color: "#ffffff"}

    {:ok, qr} =
      s
      |> QRCode.create()
      |> QRCode.render(:svg, svg_settings)

    qr
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="prose max-w-screen-xl px-3 mx-auto my-auto aspect-video" phx-window-keydown="keydown">
      <%= raw(@slides |> Enum.at(@slide)) %>
    </div>
    """
  end

  @impl true
  def handle_event("next-slide", _value, socket) do
    slide = socket.assigns.slide

    s =
      if socket.assigns.role == "controller" do
        Livedeck.Server.set_page(socket.assigns.server, slide + 1)
      else
        presenter = Livedeck.Server.get_page(socket.assigns.server)
        min(slide + 1, presenter)
      end

    {:noreply, socket |> assign(:slide, s)}
  end

  @impl true
  def handle_event("prev-slide", _value, socket) do
    slide = socket.assigns.slide

    s =
      if socket.assigns.role == "controller" do
        Livedeck.Server.set_page(socket.assigns.server, slide - 1)
      else
        max(slide - 1, 0)
      end

    {:noreply, socket |> assign(:slide, s)}
  end

  @impl true
  def handle_event("keydown", %{"key" => key}, socket) do
    case key do
      "ArrowLeft" ->
        handle_event("prev-slide", {}, socket)

      "ArrowRight" ->
        handle_event("next-slide", {}, socket)

      _ ->
        Logger.debug("Unhandled key #{key}")
        {:noreply, socket}
    end
  end

  @impl true
  def mount(%{"deck" => deck_name, "role" => role}, _session, socket) do
    s =
      "#{:code.priv_dir(:livedeck)}/decks/demo/#{deck_name}.dj"
      |> File.read!()
      |> Djot.to_html!()
      |> String.split("<hr>")

    Livedeck.DynamicSupervisor.add_child({deck_name, length(s)})

    if connected?(socket) do
      PubSub.subscribe(Livedeck.PubSub, deck_name)
      send(self(), :after_join)
    end

    livedeck_url = "#{LivedeckWeb.Endpoint.url()}/#{deck_name}/view"

    {:ok,
     socket
     |> assign(
       viewers: Presence.list(deck_name) |> map_size(),
       slide: Livedeck.Server.get_page(deck_name),
       role: role,
       server: deck_name,
       slides: s,
       themes: @themes,
       theme: hd(@themes),
       url_svg: qr(livedeck_url),
       livedeck_url: livedeck_url
     )}
  end

  @impl true
  def handle_info(%Livedeck.State{slide: s}, socket) do
    {:noreply, socket |> assign(:slide, s)}
  end

  @impl true
  def handle_info(:after_join, socket) do
    {:ok, _} =
      Presence.track(self(), socket.assigns.server, socket.id, %{
        online_at: inspect(System.system_time(:second)),
      })

    {:noreply, socket}
  end

  def handle_info(
        %Phoenix.Socket.Broadcast{
          event: "presence_diff",
          payload: %{leaves: leave, joins: join},
        },
        socket
      ) do
    {:noreply,
     socket |> assign(:viewers, socket.assigns.viewers + map_size(join) - map_size(leave))}
  end
end
