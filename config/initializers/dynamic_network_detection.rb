# Dynamic Network Detection for Home Assistant Add-on
# This runs after Rails initialization when logger is available

if ENV['HOME_ASSISTANT_ADDON'] == 'true'
  Rails.application.config.after_initialize do
    begin
      require_relative '../../lib/home_assistant_network_detector'

      Rails.logger.info "Running dynamic network detection for Home Assistant add-on"
      detected_ranges = HomeAssistantNetworkDetector.detect_network_ranges

      if detected_ranges.any?
        Rails.logger.info "Detected network ranges: #{detected_ranges}"
        # Log for informational purposes - trusted_proxies is already configured
      else
        Rails.logger.info "No additional network ranges detected, using default configuration"
      end
    rescue => e
      Rails.logger.warn "Dynamic network detection failed: #{e.message}"
      Rails.logger.warn "Continuing with static network configuration"
    end
  end
end