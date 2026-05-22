# frozen_string_literal: true

# ServerConfiguration represents connection configuration for mobile clients.
# Used to generate QR codes and server_info API responses.
class ServerConfiguration
  include ActiveModel::Model
  include ActiveModel::Serializers::JSON

  MODES = %w[local cloud home_assistant].freeze

  attr_accessor :mode, :host, :port, :use_ssl, :api_token, :ha_ingress_url,
                :server_name, :version, :capabilities, :websocket_path

  def initialize(attributes = {})
    super
    @mode ||= current_mode
    @version ||= "1.0.1"
    @capabilities ||= default_capabilities
    @websocket_path ||= "/cable"
  end

  def attributes
    {
      "mode" => mode,
      "host" => host,
      "port" => port,
      "use_ssl" => use_ssl,
      "server_name" => server_name,
      "version" => version,
      "capabilities" => capabilities,
      "websocket_path" => websocket_path,
      "ha_ingress" => home_assistant_mode?,
      "ha_ingress_url" => ha_ingress_url
    }.compact
  end

  def base_url
    scheme = use_ssl ? "https" : "http"
    port_suffix = standard_port? ? "" : ":#{port}"
    "#{scheme}://#{host}#{port_suffix}"
  end

  def websocket_url
    scheme = use_ssl ? "wss" : "ws"
    port_suffix = standard_port? ? "" : ":#{port}"
    "#{scheme}://#{host}#{port_suffix}#{websocket_path}"
  end

  def home_assistant_mode?
    mode == "home_assistant" || ENV["HOME_ASSISTANT_ADDON"] == "true"
  end

  def nabu_casa_url
    return nil unless home_assistant_mode?
    ENV["NABU_CASA_URL"]
  end

  def to_qr_payload(token: nil)
    {
      url: base_url,
      mode: mode,
      token: token,
      ws: websocket_url,
      ha: home_assistant_mode?
    }.compact.to_json
  end

  private

  def current_mode
    return "home_assistant" if ENV["HOME_ASSISTANT_ADDON"] == "true"
    ENV.fetch("DISCOVERY_MODE", "local")
  end

  def default_capabilities
    %w[chat api webhooks realtime]
  end

  def standard_port?
    return true if port.nil?
    (use_ssl && port == 443) || (!use_ssl && port == 80)
  end
end
