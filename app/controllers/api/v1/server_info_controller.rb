# frozen_string_literal: true

class Api::V1::ServerInfoController < Api::V1::BaseController
  skip_before_action :authenticate_api_request, only: [ :show ]

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
      push_enabled: FcmNotificationService.fcm_configured?,
      api_version: "1.0.0",
      min_client_version: "1.0.0",
      e2ee_enabled: true,
      e2ee_required_private_dm: true,
      min_e2ee_version: E2eePolicy::REQUIRED_VERSION,
      e2ee_capabilities: {
        channel_scope: E2eePolicy::ENFORCED_CHANNEL_TYPES,
        legacy_write_blocked: true,
        bot_posting_blocked: true,
        encrypted_attachments: false,
        plaintext_attachments_blocked_in_e2ee: true
      },
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
    Setting.registration_enabled?
  end
end
