# Home Assistant Network Detection Utility
# Dynamically detects network ranges for trusted proxies configuration
class HomeAssistantNetworkDetector
  def self.detect_network_ranges
    return [] unless ENV['HOME_ASSISTANT_ADDON'] == 'true'

    ranges = []

    # Add detected ranges from various methods
    ranges.concat(detect_from_supervisor_api)
    ranges.concat(detect_from_ip_route)
    ranges.concat(detect_from_network_interfaces)
    ranges.concat(detect_from_environment)

    # Remove duplicates and invalid ranges
    ranges.compact.uniq.select { |range| valid_ip_range?(range) }
  end

  private

  # Detect network ranges using Home Assistant Supervisor API
  def self.detect_from_supervisor_api
    return [] unless ENV['SUPERVISOR_TOKEN']

    begin
      Rails.logger.info "Attempting to detect network ranges via Supervisor API"

      # Make API call to supervisor
      require 'net/http'
      require 'json'

      uri = URI('http://supervisor/network/info')
      http = Net::HTTP.new(uri.host, uri.port)
      http.read_timeout = 5

      request = Net::HTTP::Get.new(uri)
      request['Authorization'] = "Bearer #{ENV['SUPERVISOR_TOKEN']}"
      request['Content-Type'] = 'application/json'

      response = http.request(request)

      if response.code == '200'
        network_info = JSON.parse(response.body)
        ranges = extract_ranges_from_supervisor_response(network_info)
        Rails.logger.info "Detected network ranges from Supervisor API: #{ranges}"
        return ranges
      else
        Rails.logger.warn "Supervisor API returned #{response.code}: #{response.body}"
      end
    rescue => e
      Rails.logger.warn "Failed to detect network via Supervisor API: #{e.message}"
    end

    []
  end

  # Extract network ranges from supervisor API response
  def self.extract_ranges_from_supervisor_response(network_info)
    ranges = []

    # Parse network interfaces
    if network_info['data'] && network_info['data']['interfaces']
      network_info['data']['interfaces'].each do |interface|
        # Extract IPv4 ranges
        if interface['ipv4'] && interface['ipv4']['address']
          ip = interface['ipv4']['address'].first
          prefix = interface['ipv4']['prefix'] || 24

          if ip && prefix
            network = calculate_network_range(ip, prefix)
            ranges << network if network
          end
        end

        # Extract IPv6 ranges if needed
        if interface['ipv6'] && interface['ipv6']['address']
          interface['ipv6']['address'].each do |ipv6_addr|
            # IPv6 handling could be added here if needed
          end
        end
      end
    end

    ranges
  end

  # Detect network ranges using ip route command
  def self.detect_from_ip_route
    ranges = []

    begin
      Rails.logger.info "Attempting to detect network ranges via ip route"

      # Get default route
      default_route = `ip route show default 2>/dev/null`.strip
      if default_route.present?
        # Extract interface from default route
        interface = default_route.match(/dev\s+(\w+)/i)&.captures&.first

        if interface
          # Get network range for this interface
          route_info = `ip route show dev #{interface} 2>/dev/null`.strip
          route_info.split("\n").each do |route|
            # Look for local network routes (not default)
            if route.match(/^(\d+\.\d+\.\d+\.\d+\/\d+)/) && !route.include?('default')
              network = $1
              ranges << network if valid_ip_range?(network)
            end
          end
        end
      end

      Rails.logger.info "Detected network ranges from ip route: #{ranges}" if ranges.any?
    rescue => e
      Rails.logger.warn "Failed to detect network via ip route: #{e.message}"
    end

    ranges
  end

  # Detect network ranges from system network interfaces
  def self.detect_from_network_interfaces
    ranges = []

    begin
      Rails.logger.info "Attempting to detect network ranges via network interfaces"

      # Use ip addr command to get interface information
      interfaces_output = `ip addr show 2>/dev/null`

      interfaces_output.scan(/inet\s+(\d+\.\d+\.\d+\.\d+\/\d+)/) do |match|
        ip_with_cidr = match.first
        # Skip loopback addresses
        next if ip_with_cidr.start_with?('127.')
        # Skip link-local addresses
        next if ip_with_cidr.start_with?('169.254.')

        ranges << ip_with_cidr if valid_ip_range?(ip_with_cidr)
      end

      Rails.logger.info "Detected network ranges from interfaces: #{ranges}" if ranges.any?
    rescue => e
      Rails.logger.warn "Failed to detect network via interfaces: #{e.message}"
    end

    ranges
  end

  # Detect from environment variables or other sources
  def self.detect_from_environment
    ranges = []

    # Check for any network-related environment variables
    if ENV['NETWORK_RANGE']
      ranges << ENV['NETWORK_RANGE']
    end

    # Add common Docker network ranges that might be used by HA
    docker_ranges = [
      '172.30.0.0/16',  # Common HA supervisor network
      '172.17.0.0/16',  # Default Docker bridge
      '172.18.0.0/16',  # Docker compose networks
    ]

    ranges.concat(docker_ranges)

    Rails.logger.info "Added environment/Docker network ranges: #{ranges}" if ranges.any?
    ranges
  end

  # Calculate network range from IP and prefix
  def self.calculate_network_range(ip, prefix)
    require 'ipaddr'
    IPAddr.new("#{ip}/#{prefix}").to_s
  rescue
    nil
  end

  # Validate IP range format
  def self.valid_ip_range?(range)
    return false unless range.is_a?(String)

    # Check for CIDR notation
    return false unless range.include?('/')

    begin
      IPAddr.new(range)
      true
    rescue
      false
    end
  end

  # Convert network ranges to IPAddr objects for Rails trusted_proxies
  def self.to_ipaddr_objects(ranges)
    ranges.map do |range|
      begin
        IPAddr.new(range)
      rescue
        Rails.logger.warn "Invalid IP range: #{range}"
        nil
      end
    end.compact
  end
end