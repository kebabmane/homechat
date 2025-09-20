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

  # Enhanced logging for debugging in Home Assistant environment
  Rails.logger.info "Home Assistant add-on CSRF protection configured with null_session mode"
end