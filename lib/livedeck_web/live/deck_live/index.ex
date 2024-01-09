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
    <%= raw(@url_svg) %><br />Open slides: <%= @livedeck_url %>
    <br />
    <%= raw(@control_url_svg) %><br />Take control: <%= @control_url %>
    <br />
    <div class="prose">
      <%= raw(@slides |> Enum.at(@slide)) %>
    </div>
    <div class="flex items-center justify-between border-b border-zinc-100 py-3 text-sm">
      <div class="flex items-center gap-4">
        <.button phx-click="prev-slide">&lt;</.button>
      </div>
      <div class="flex">
        <p><%= @slide + 1 %> / <%= Enum.count(@slides) %></p>
      </div>
      <div class="flex items-center gap-4 font-semibold leading-6">
        <.button phx-click="next-slide">&gt;</.button>
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
