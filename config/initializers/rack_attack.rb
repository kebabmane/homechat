# Configure Rack::Attack for rate limiting and security
#
# Rack::Attack is a rack middleware for blocking & throttling abusive requests

# Disable Rack::Attack in test environment
Rack::Attack.enabled = !Rails.env.test?

class Rack::Attack
  ### Configure Cache ###

  # Use Rails cache store for tracking request counts
  Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new

  ### Throttle (Rate Limit) ###

  # Throttle all requests by IP (general limit)
  #
  # Key: "req/ip:#{req.ip}"
  throttle('req/ip', limit: 300, period: 5.minutes) do |req|
    req.ip unless req.path.start_with?('/assets')
  end

  # Throttle POST requests to /signin by IP address
  #
  # Key: "logins/ip:#{req.ip}"
  throttle('logins/ip', limit: 5, period: 20.seconds) do |req|
    if req.path == '/signin' && req.post?
      req.ip
    end
  end

  # Throttle POST requests to /signup by IP address
  #
  # Key: "signups/ip:#{req.ip}"
  throttle('signups/ip', limit: 3, period: 1.hour) do |req|
    if req.path == '/users' && req.post?
      req.ip
    end
  end

  # Throttle POST requests to API signin endpoint
  #
  # Key: "api_logins/ip:#{req.ip}"
  throttle('api_logins/ip', limit: 5, period: 20.seconds) do |req|
    if req.path == '/api/v1/signin' && req.post?
      req.ip
    end
  end

  # Throttle API requests by IP address
  #
  # Key: "api/ip:#{req.ip}"
  throttle('api/ip', limit: 100, period: 1.minute) do |req|
    if req.path.start_with?('/api/')
      req.ip
    end
  end

  # Throttle message creation to prevent spam
  #
  # Key: "messages/ip:#{req.ip}"
  throttle('messages/ip', limit: 30, period: 1.minute) do |req|
    if req.path.match?(%r{/api/v1/(messages|channels/.+/messages)}) && req.post?
      req.ip
    end
  end

  ### Custom Throttle Response ###
  self.throttled_responder = lambda do |req|
    match_data = req.env['rack.attack.match_data']
    now = match_data[:epoch_time]

    headers = {
      'Content-Type' => 'application/json',
      'X-RateLimit-Limit' => match_data[:limit].to_s,
      'X-RateLimit-Remaining' => '0',
      'X-RateLimit-Reset' => (now + (match_data[:period] - now % match_data[:period])).to_s
    }

    body = {
      error: 'Rate limit exceeded. Please try again later.',
      retry_after: match_data[:period]
    }.to_json

    [429, headers, [body]]
  end

  ### Logging ###
  ActiveSupport::Notifications.subscribe('rack.attack') do |name, start, finish, request_id, payload|
    req = payload[:request]
    if [:throttle, :blocklist].include? req.env['rack.attack.match_type']
      Rails.logger.warn "[Rack::Attack][#{req.env['rack.attack.match_type']}] " \
                        "ip: #{req.ip}, path: #{req.path}"
    end
  end
end
