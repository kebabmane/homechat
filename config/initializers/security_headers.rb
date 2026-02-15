# Configure security headers for the application

Rails.application.config.action_dispatch.default_headers = {
  # Prevent MIME type sniffing
  'X-Content-Type-Options' => 'nosniff',

  # Enable XSS protection (legacy browsers)
  'X-XSS-Protection' => '1; mode=block',

  # Prevent clickjacking (overridden for Home Assistant)
  'X-Frame-Options' => ENV['HOME_ASSISTANT_ADDON'] == 'true' ? 'ALLOWALL' : 'SAMEORIGIN',

  # Control referrer information
  'Referrer-Policy' => 'strict-origin-when-cross-origin',

  # Permissions Policy (formerly Feature Policy)
  'Permissions-Policy' => 'camera=(), microphone=(), geolocation=(), interest-cohort=()',

  # Strict Transport Security (HSTS) - 1 year
  'Strict-Transport-Security' => 'max-age=31536000; includeSubDomains'
}

# Configure Content Security Policy with nonce-based script loading
Rails.application.config.content_security_policy do |policy|
  policy.default_src :self
  policy.font_src    :self, :https, :data
  policy.img_src     :self, :https, :data, :blob
  policy.object_src  :none
  policy.frame_ancestors :self

  # Script sources: prefer nonce-based, fall back to unsafe-inline for compatibility
  # When nonce is provided via content_security_policy_nonce_generator, scripts with
  # matching nonce will be allowed. The 'strict-dynamic' directive propagates trust.
  if Rails.env.production?
    # Production: use nonces with strict-dynamic for better security
    # Note: unsafe-inline is ignored when nonces are present in supporting browsers
    policy.script_src :self, :unsafe_inline, :strict_dynamic
  else
    # Development: more permissive for easier debugging
    policy.script_src :self, :unsafe_inline
  end

  # Style sources: unsafe-inline needed for Tailwind's runtime styles
  # Allow Google Fonts stylesheets
  policy.style_src :self, :unsafe_inline, 'https://fonts.googleapis.com'

  # Allow ActionCable WebSocket connections
  if Rails.env.development?
    policy.connect_src :self, :https, 'ws://localhost:*', 'wss://localhost:*', 'http://localhost:*'
  else
    policy.connect_src :self, :https, :wss
  end

  # Base URI restriction
  policy.base_uri :self

  # Form action restriction
  policy.form_action :self

  # Specify URI for violation reports (uncomment to enable)
  # policy.report_uri "/api/v1/csp-reports"
end

# Generate session nonces for permitted importmap and inline scripts
# The nonce is automatically added to script tags when using javascript_include_tag
Rails.application.config.content_security_policy_nonce_generator = ->(request) {
  # Use the request_id for consistency across the request lifecycle
  # This ensures the same nonce is used for all script tags in a single request
  request.session.id.to_s.presence || SecureRandom.base64(24)
}

# Apply nonces to script-src directive
Rails.application.config.content_security_policy_nonce_directives = %w[script-src]

# Report-Only mode for testing CSP changes without breaking functionality
# Uncomment to test CSP changes before enforcing
# Rails.application.config.content_security_policy_report_only = true

# Configure secure session cookies based on access mode
# RAILS_ASSUME_SSL=true means we're behind a reverse proxy (HA Ingress) that handles SSL
# RAILS_ASSUME_SSL=false means direct access (HTTP or direct SSL)
if ENV['HOME_ASSISTANT_ADDON'] == 'true'
  if ENV['RAILS_ASSUME_SSL'] == 'true'
    # Home Assistant Ingress mode: accessed through HA's SSL-terminating proxy
    # Requires SameSite=None for cross-origin iframe, and Secure for SameSite=None
    Rails.application.config.session_store :cookie_store,
      key: '_homechat_session',
      secure: true,
      httponly: true,
      same_site: :none
  else
    # Direct access mode (HTTP or direct SSL): standard cookie settings
    Rails.application.config.session_store :cookie_store,
      key: '_homechat_session',
      secure: false,
      httponly: true,
      same_site: :lax
  end
else
  Rails.application.config.session_store :cookie_store,
    key: '_homechat_session',
    secure: Rails.env.production?,
    httponly: true,
    same_site: :lax
end
