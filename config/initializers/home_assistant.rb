# Home Assistant Add-on Configuration
# This initializer handles specific configuration for when HomeChat runs as a Home Assistant add-on

if ENV['HOME_ASSISTANT_ADDON'] == 'true'
  Rails.application.configure do
    # Log configuration for Home Assistant environment
    Rails.logger.info "HomeChat running in Home Assistant add-on mode"

    # Enhanced logging for debugging ingress issues
    config.log_level = :info
    Rails.logger.info "Home Assistant add-on configuration loaded"
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
      # Enhanced logging for debugging CSRF issues
      Rails.logger.info "CSRF verification check in Home Assistant mode"
      Rails.logger.info "Request format: #{request.format}"
      Rails.logger.info "Request method: #{request.method}"
      Rails.logger.info "Request path: #{request.path}"
      Rails.logger.info "Remote IP: #{request.remote_ip}"
      Rails.logger.info "X-Forwarded-For: #{request.headers['X-Forwarded-For']}"
      Rails.logger.info "X-Ingress-Path: #{request.headers['X-Ingress-Path']}"
      Rails.logger.info "Origin: #{request.headers['Origin']}"
      Rails.logger.info "Referer: #{request.headers['Referer']}"

      # Log CSRF token information
      submitted_token = request.headers['X-CSRF-Token'] || params[request_forgery_protection_token]
      session_token = session[:_csrf_token] if session.respond_to?(:key?) && session.key?(:_csrf_token)
      Rails.logger.info "Submitted token present: #{!submitted_token.nil?}"
      Rails.logger.info "Session token present: #{!session_token.nil?}"
      Rails.logger.info "Authenticity token param: #{params[:authenticity_token].present?}"

      # Try the standard verification first
      standard_result = super
      Rails.logger.info "Standard CSRF verification result: #{standard_result}"
      return true if standard_result

      # If we're in Home Assistant and this is a form submission, be more lenient
      if ENV['HOME_ASSISTANT_ADDON'] == 'true'
        # Handle HTML forms and Turbo Stream requests
        if (request.format.html? || request.format.turbo_stream?) &&
           (request.post? || request.patch? || request.put? || request.delete?)

          Rails.logger.warn "CSRF verification failed for #{request.format} #{request.method} request"

          # Check if we have a valid session (user is signed in)
          # This provides some security while working around ingress CSRF issues
          if session[:user_id].present?
            Rails.logger.warn "Allowing request due to valid user session in HA add-on mode"
            return true
          end

          # Check if this is a signup request (no session required)
          if request.path == '/signup' && request.post?
            Rails.logger.warn "Allowing signup request in HA add-on mode"
            return true
          end

          # Check if this is a signin request (no session required)
          if request.path == '/signin' && request.post?
            Rails.logger.warn "Allowing signin request in HA add-on mode"
            return true
          end
        end
      end

      Rails.logger.warn "CSRF verification failed and no fallback conditions met"
      false
    end
  end

  # Apply the patch to ApplicationController
  Rails.configuration.to_prepare do
    ApplicationController.prepend HomeAssistantCSRFPatch
  end
end