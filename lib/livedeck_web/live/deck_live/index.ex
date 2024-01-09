defmodule LivedeckWeb.DeckLive.Index do
  use LivedeckWeb, :live_view
  alias QRCode.Render.SvgSettings
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
    {:noreply, socket |> assign(:slide, min(slide + 1, Enum.count(socket.assigns.slides) - 1))}
  end

  @impl true
  def handle_event("prev-slide", _value, socket) do
    slide = socket.assigns.slide
    {:noreply, socket |> assign(:slide, max(slide - 1, 0))}
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
    Livedeck.DynamicSupervisor.add_child("deck")

    if connected?(socket) do
      Livedeck.Server.add("deck", socket.id)
    end

    Logger.info(Livedeck.Server.log("deck"))

    s =
      "#{:code.priv_dir(:livedeck)}/decks/demo/hello.dj"
      |> File.read!()
      |> Djot.to_html!()
      |> String.split("<hr>")

    {:ok, socket |> assign(:server, "deck") |> assign(:slides, s) |> assign(:slide, 0)}
  end
end
