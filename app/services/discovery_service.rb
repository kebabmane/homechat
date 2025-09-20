require 'dnssd'

class DiscoveryService
  SERVICE_TYPE = '_homechat._tcp.'
  SERVICE_DOMAIN = 'local.'

  attr_reader :server_name, :port, :txt_record

  def initialize(server_name: nil, port: nil)
    @server_name = server_name || default_server_name
    @port = port || default_port
    @txt_record = build_txt_record
    @service = nil
    @running = false
  end

  def start
    return if @running

    begin
      @service = DNSSD.register(
        @server_name,
        SERVICE_TYPE,
        SERVICE_DOMAIN,
        @port,
        @txt_record
      )
      @running = true
      Rails.logger.info "HomeChat discovery service started: #{@server_name} on port #{@port}"
    rescue => e
      Rails.logger.error "Failed to start discovery service: #{e.message}"
      raise
    end
  end

  def stop
    return unless @running && @service

    begin
      # DNSSD service cleanup - the service will be garbage collected
      # Stop method for DNSSD service if it exists, otherwise just clear the reference
      if @service.respond_to?(:stop)
        @service.stop
      elsif @service.respond_to?(:close)
        @service.close
      end

      @service = nil
      @running = false
      Rails.logger.info "HomeChat discovery service stopped"
    rescue => e
      Rails.logger.error "Error stopping discovery service: #{e.message}"
      # Force cleanup even if there's an error
      @service = nil
      @running = false
    end
  end

  def running?
    @running
  end

  def restart
    stop
    start
  end

  private

  def default_server_name
    hostname = Socket.gethostname
    app_name = Rails.application.class.module_parent_name
    "#{app_name} on #{hostname}"
  end

  def default_port
    Rails.env.development? ? 3000 : 80
  end

  def build_txt_record
    DNSSD::TextRecord.new(
      'version' => '1.0',
      'platform' => 'rails',
      'features' => 'chat,api,webhooks',
      'secure' => Rails.env.production? ? 'true' : 'false'
    )
  end
end