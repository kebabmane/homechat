class HomeController < ApplicationController
  layout 'authentication'

  skip_before_action :mark_active, raise: false
  skip_before_action :set_sidebar_data, raise: false

  def index
    @server_config = build_server_configuration
    @qr_payload = @server_config.to_qr_payload
    @qr_code = RQRCode::QRCode.new(@qr_payload)
  end

  private

  def build_server_configuration
    ServerConfiguration.new(
      host: request.host,
      port: request.port,
      use_ssl: request.ssl?,
      server_name: Setting.fetch(:site_name, 'HomeChat')
    )
  end
end
