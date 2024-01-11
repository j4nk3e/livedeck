defmodule LivedeckWeb.DeckLive.Index do
  use LivedeckWeb, :live_view
  alias QRCode.Render.SvgSettings
  alias Phoenix.PubSub
  require Logger

  defp qr(s) do
    svg_settings = %SvgSettings{background_opacity: 0, qrcode_color: {255, 255, 255}}

    {:ok, qr} =
      s
      |> QRCode.create()
      |> QRCode.render(:svg, svg_settings)

    qr
  end

  @impl true
  def render(assigns) do
    livedeck_url = LivedeckWeb.Endpoint.url()
    control_url = "#{livedeck_url}/control"

    assigns =
      assigns
      |> assign(:url_svg, qr(livedeck_url))
      |> assign(:livedeck_url, livedeck_url)
      |> assign(:control_url, control_url)
      |> assign(:control_url_svg, qr(control_url))

    ~H"""
    <div class="prose mb-10" phx-window-keydown="keydown">
      <p><%= raw(@url_svg) %>Open slides: <%= @livedeck_url %></p>
      <p><%= raw(@control_url_svg) %>Take control: <%= @control_url %></p>
      <%= raw(@slides |> Enum.at(@slide)) %>
    </div>
    <div class="flex items-center justify-between border-t border-zinc-100 py-3 text-sm">
      <div class="flex items-center gap-4">
        <.button phx-click="prev-slide" class="btn" disabled={@slide == 0}>&lt;</.button>
      </div>
      <div class="flex">
        <p><%= @slide + 1 %> / <%= Enum.count(@slides) %></p>
      </div>
      <div class="flex items-center gap-4 font-semibold leading-6">
        <.button phx-click="next-slide" class="btn" disabled={@slide == Enum.count(@slides) - 1}>
          &gt;
        </.button>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("next-slide", _value, socket) do
    slide = socket.assigns.slide
    slide = min(slide + 1, Enum.count(socket.assigns.slides) - 1)
    Livedeck.Server.page(socket.assigns.server, slide)
    {:noreply, socket |> assign(:slide, slide)}
  end

  @impl true
  def handle_event("prev-slide", _value, socket) do
    slide = socket.assigns.slide
    slide = max(slide - 1, 0)
    Livedeck.Server.page(socket.assigns.server, slide)
    {:noreply, socket |> assign(:slide, slide)}
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
  def mount(_params, _session, socket) do
    deck_name = "deck"
    Livedeck.DynamicSupervisor.add_child(deck_name)

    socket = if connected?(socket) do
      PubSub.subscribe(Livedeck.PubSub, deck_name)
      state = Livedeck.Server.add(deck_name, socket.id)

      socket
      |> assign(:slide, state.slide)
      |> assign(:viewers, map_size(state.viewers))
    else
      socket
      |> assign(:slide, 0)
      |> assign(:viewers, 0)
    end

    Logger.info(Livedeck.Server.log(deck_name))

    s =
      "#{:code.priv_dir(:livedeck)}/decks/demo/hello.dj"
      |> File.read!()
      |> Djot.to_html!()
      |> String.split("<hr>")

    {:ok,
     socket
     |> assign(:server, deck_name)
     |> assign(:slides, s)}
  end

  @impl true
  def handle_info(%Livedeck.State{slide: s, viewers: v}, socket) do
    {:noreply, socket |> assign(:slide, s) |> assign(:viewers, map_size(v))}
  end
end
