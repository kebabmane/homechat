# Start discovery service after Rails initialization
Rails.application.config.after_initialize do
    # Skip discovery service in Home Assistant add-on mode to avoid conflicts
    if Rails.application.config.discovery.enabled && ENV['HOME_ASSISTANT_ADDON'] != 'true'
      discovery_service = DiscoveryService.new(
        server_name: Rails.application.config.discovery.server_name,
        port: Rails.application.config.discovery.port
      )

      # Store the service instance for graceful shutdown
      Rails.application.config.discovery_service = discovery_service

      begin
        discovery_service.start
      rescue => e
        Rails.logger.warn "Could not start discovery service: #{e.message}"
        Rails.logger.warn "HomeChat will continue without LAN discovery"
      end
    end
end

# Graceful shutdown hook
at_exit do
  if defined?(Rails) && Rails.application.config.respond_to?(:discovery_service)
    service = Rails.application.config.discovery_service
    service&.stop
  end
end