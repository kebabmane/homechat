# Home Assistant Add-on Configuration
# This initializer handles specific configuration for when HomeChat runs as a Home Assistant add-on

if ENV['HOME_ASSISTANT_ADDON'] == 'true'
  Rails.application.configure do
    # Log configuration for Home Assistant environment
    Rails.logger.info "HomeChat running in Home Assistant add-on mode"

    # Configure middleware for ingress proxy
    config.middleware.insert_before ActionDispatch::Session::CookieStore, Rack::MethodOverride

    # Additional CSRF token configuration for Home Assistant ingress
    config.action_controller.forgery_protection_origin_check = false

    # Allow iframe embedding in Home Assistant
    config.force_ssl = false
    config.ssl_options = { redirect: false }

    # Trust all origins when running in Home Assistant (controlled environment)
    config.action_dispatch.trusted_proxies = ActionDispatch::RemoteIp::TRUSTED_PROXIES + [
      IPAddr.new('172.30.33.0/24'),  # Home Assistant supervisor network
      IPAddr.new('172.30.32.0/24'),  # Alternative HA network
      IPAddr.new('10.0.0.0/8'),      # Common internal networks
      IPAddr.new('192.168.0.0/16'),
      IPAddr.new('172.16.0.0/12')
    ]

    # Configure for Home Assistant's ingress path handling
    config.relative_url_root = ENV['X_INGRESS_PATH'] if ENV['X_INGRESS_PATH'].present?

    # Enhanced logging for debugging proxy issues
    config.log_level = :info
    Rails.logger.info "Home Assistant add-on configuration loaded"
    Rails.logger.info "X-Ingress-Path: #{ENV['X_INGRESS_PATH']}" if ENV['X_INGRESS_PATH']
  end

  # Custom middleware to handle Home Assistant ingress headers
  class HomeAssistantIngressMiddleware
    def initialize(app)
      @app = app
    end

    def call(env)
      # Extract and log ingress path for debugging
      ingress_path = env['HTTP_X_INGRESS_PATH']
      if ingress_path
        Rails.logger.debug "Ingress Path: #{ingress_path}"

        # Store ingress path in request environment for use in controllers
        env['homechat.ingress_path'] = ingress_path
      end

      # Log relevant headers for debugging
      Rails.logger.debug "X-Forwarded-Proto: #{env['HTTP_X_FORWARDED_PROTO']}"
      Rails.logger.debug "X-Forwarded-For: #{env['HTTP_X_FORWARDED_FOR']}"
      Rails.logger.debug "Origin: #{env['HTTP_ORIGIN']}"

      @app.call(env)
    end
  end

  # Insert the middleware
  Rails.application.config.middleware.use HomeAssistantIngressMiddleware

  # Override CSRF token validation for specific scenarios
  module HomeAssistantCSRFPatch
    def verified_request?
      # Log the verification attempt
      Rails.logger.debug "CSRF verification check in Home Assistant mode"
      Rails.logger.debug "Form authenticity token: #{form_authenticity_token}"
      Rails.logger.debug "Request authenticity token: #{request.headers['X-CSRF-Token'] || params[request_forgery_protection_token]}"

      # If we're in Home Assistant and this is a form post, be more lenient
      if request.format.html? && request.post? && ENV['HOME_ASSISTANT_ADDON'] == 'true'
        # Try the standard verification first
        return true if super

        # If that fails, check if we have a valid session (indicating user is logged in)
        # This provides some security while working around ingress CSRF issues
        if session[:user_id].present?
          Rails.logger.warn "CSRF verification failed but allowing due to valid session in HA add-on mode"
          return true
        end
      end

      super
    end
  end

  # Apply the patch to ApplicationController
  Rails.configuration.to_prepare do
    ApplicationController.prepend HomeAssistantCSRFPatch
  end
end