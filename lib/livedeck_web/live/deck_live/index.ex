defmodule LivedeckWeb.DeckLive.Index do
  use LivedeckWeb, :live_view
  alias QRCode.Render.SvgSettings

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
