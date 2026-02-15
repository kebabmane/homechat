# frozen_string_literal: true

class Api::V1::ServerInfoController < Api::V1::BaseController
  skip_before_action :authenticate_api_request, only: [:show]

  # GET /api/v1/server_info
  # Public endpoint for clients to discover server capabilities and connection info
  def show
    config = build_server_configuration

    render json: {
      server_name: config.server_name,
      version: config.version,
      mode: config.mode,
      capabilities: config.capabilities,
      websocket_path: config.websocket_path,
      ha_ingress: config.home_assistant_mode?,
      nabu_casa_url: config.nabu_casa_url,
      push_enabled: Setting.fcm_configured?,
      registration_enabled: registration_enabled?,
      timestamp: Time.current.iso8601
    }.compact
  end

  private

  def build_server_configuration
    ServerConfiguration.new(
      host: request.host,
      port: request.port,
      use_ssl: request.ssl?,
      server_name: discovery_server_name
    )
  end

  def discovery_server_name
    Rails.application.config.discovery.server_name ||
      "HomeChat on #{Socket.gethostname}"
  end

  def registration_enabled?
    Setting.respond_to?(:registration_enabled?) ? Setting.registration_enabled? : true
  end
end
