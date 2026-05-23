# Discovery mode configuration
# - local: mDNS/Bonjour discovery on local network (default)
# - cloud: Manual URL configuration, mDNS disabled
# - disabled: No discovery service
DISCOVERY_MODE = ENV.fetch("DISCOVERY_MODE", "local").freeze

# Home Assistant addon mode - mDNS cannot work due to Docker network isolation
HA_ADDON_MODE = ENV["HOME_ASSISTANT_ADDON"] == "true"

# Start discovery service after Rails initialization
Rails.application.config.after_initialize do
    # Store the discovery mode in app config for access elsewhere
    Rails.application.config.discovery.mode = DISCOVERY_MODE

    # mDNS discovery cannot work in HA addon mode due to Docker network isolation
    # The container's network is isolated from the host's physical network
    if HA_ADDON_MODE
      Rails.logger.info "Discovery: Disabled in Home Assistant addon mode (Docker network isolation)"
      Rails.logger.info "iOS app setup: Use QR code or enter server URL manually"
      next
    end

    # Start discovery service for LAN discovery (only in 'local' mode)
    # Cloud deployments (VPS, EC2, etc.) should set DISCOVERY_MODE=cloud
    should_start_mdns = Rails.application.config.discovery.enabled &&
                        DISCOVERY_MODE == "local"

    if should_start_mdns
      discovery_service = DiscoveryService.new(
        server_name: Rails.application.config.discovery.server_name,
        port: Rails.application.config.discovery.port
      )

      # Store the service instance for graceful shutdown
      Rails.application.config.discovery_service = discovery_service

      begin
        discovery_service.start
        Rails.logger.info "Discovery mode: local (mDNS enabled)"
      rescue => e
        Rails.logger.warn "Could not start discovery service: #{e.class}"
        Rails.logger.warn "HomeChat will continue without LAN discovery"
      end
    else
      Rails.logger.info "Discovery mode: #{DISCOVERY_MODE} (mDNS disabled)"
    end
end

# Graceful shutdown hook
at_exit do
  if defined?(Rails) && Rails.application.config.respond_to?(:discovery_service)
    service = Rails.application.config.discovery_service
    service&.stop
  end
end
