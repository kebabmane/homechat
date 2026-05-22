class HomeController < ApplicationController
  layout "authentication"

  QR_SVG_OPTIONS = {
    color: "000",
    shape_rendering: "crispEdges",
    module_size: 4,
    standalone: true,
    use_path: true
  }.freeze

  skip_before_action :mark_active, raise: false
  skip_before_action :set_sidebar_data, raise: false

  def index
    @server_config = build_server_configuration
    @qr_payload = @server_config.to_qr_payload
    @qr_svg = Rails.cache.fetch([ "mobile-setup-qr-svg", @qr_payload ], expires_in: 12.hours) do
      RQRCode::QRCode.new(@qr_payload).as_svg(**QR_SVG_OPTIONS)
    end
  end

  private

  def build_server_configuration
    ServerConfiguration.new(
      host: request.host,
      port: request.port,
      use_ssl: request.ssl?,
      server_name: Setting.fetch(:site_name, "HomeChat")
    )
  end
end
