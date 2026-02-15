# CORS (Cross-Origin Resource Sharing) Configuration
#
# This file configures CORS for the HomeChat API. CORS is required when:
# - Mobile apps make requests from a different origin
# - Web clients are hosted on a different domain
# - Third-party integrations need to access the API
#
# SECURITY NOTE: Be careful with CORS settings in production.
# Only allow origins you trust.

# Uncomment and configure if you need CORS support
# You'll also need to add 'rack-cors' to your Gemfile:
#   gem 'rack-cors'

# Rails.application.config.middleware.insert_before 0, Rack::Cors do
#   # API endpoints - allow from specific origins
#   allow do
#     # Origins that are allowed to access the API
#     # In production, list specific domains instead of '*'
#     origins ENV.fetch('CORS_ALLOWED_ORIGINS', 'http://localhost:3000').split(',')
#
#     resource '/api/*',
#       headers: :any,
#       methods: [:get, :post, :put, :patch, :delete, :options, :head],
#       credentials: true,  # Allow cookies/auth headers
#       max_age: 86400,     # Cache preflight for 24 hours
#       expose: ['X-Request-Id', 'X-RateLimit-Limit', 'X-RateLimit-Remaining']
#   end
#
#   # WebSocket connections (ActionCable)
#   allow do
#     origins ENV.fetch('CORS_ALLOWED_ORIGINS', 'http://localhost:3000').split(',')
#
#     resource '/cable',
#       headers: :any,
#       methods: [:get, :post, :options],
#       credentials: true
#   end
# end

# ============================================================================
# CORS CONFIGURATION GUIDE
# ============================================================================
#
# 1. DEVELOPMENT
#    Set CORS_ALLOWED_ORIGINS to your local development URLs:
#    CORS_ALLOWED_ORIGINS=http://localhost:3000,http://localhost:8080
#
# 2. PRODUCTION
#    Set CORS_ALLOWED_ORIGINS to your production domains:
#    CORS_ALLOWED_ORIGINS=https://chat.example.com,https://app.example.com
#
# 3. MOBILE APPS
#    Mobile apps typically don't need CORS as they're not subject to
#    browser same-origin policy. However, if using a WebView that
#    enforces CORS, add the app's origin.
#
# 4. HOME ASSISTANT
#    When running as a Home Assistant add-on, CORS is typically not needed
#    as requests come through the HA ingress proxy.
#
# 5. SECURITY CONSIDERATIONS
#    - NEVER use origins: '*' with credentials: true in production
#    - Use specific domain names, not wildcards
#    - Consider using a reverse proxy (nginx, traefik) for CORS instead
#    - Review exposed headers carefully
#
# 6. TESTING CORS
#    Use curl to test CORS preflight:
#    curl -X OPTIONS http://localhost:3000/api/v1/messages \
#      -H "Origin: http://example.com" \
#      -H "Access-Control-Request-Method: POST" \
#      -H "Access-Control-Request-Headers: Authorization" \
#      -v
#
# ============================================================================
