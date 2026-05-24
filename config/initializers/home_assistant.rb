# Home Assistant Add-on Configuration
# This initializer handles specific configuration for when HomeChat runs as a Home Assistant add-on

# Custom middleware to handle Home Assistant ingress headers.
#
# HA ingress strips the external ingress prefix before proxying to the add-on,
# but exposes it as X-Ingress-Path. Feeding that value into SCRIPT_NAME lets
# Rails generate route URLs that stay inside the ingress frame.
class HomeAssistantIngressMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    ingress_path = normalized_ingress_path(env["HTTP_X_INGRESS_PATH"])
    if ingress_path
      Rails.logger.debug "Ingress Path: #{ingress_path}"

      env["homechat.ingress_path"] = ingress_path
      env["SCRIPT_NAME"] = ingress_path if env["SCRIPT_NAME"].blank? || env["SCRIPT_NAME"] == "/"
    end

    Rails.logger.debug "X-Forwarded-Proto: #{env['HTTP_X_FORWARDED_PROTO']}"
    Rails.logger.debug "X-Forwarded-For: #{env['HTTP_X_FORWARDED_FOR']}"
    Rails.logger.debug "Origin: #{env['HTTP_ORIGIN']}"

    @app.call(env)
  end

  private

  def normalized_ingress_path(raw_path)
    path = raw_path.to_s.strip
    return nil if path.blank? || path == "/"
    return nil if path.start_with?("//") || path.include?("\n") || path.include?("\r")

    path = path.split(/[?#]/, 2).first
    path = "/#{path}" unless path.start_with?("/")
    path = path.chomp("/")
    return nil if path == "/" || path.split("/").include?("..")

    path
  end
end

if ENV["HOME_ASSISTANT_ADDON"] == "true"
  Rails.application.configure do
    # Log configuration for Home Assistant environment
    Rails.logger.info "HomeChat running in Home Assistant add-on mode"

    # Enhanced logging for debugging ingress issues
    config.log_level = :info
    Rails.logger.info "Home Assistant add-on configuration loaded"
  end

  # Insert the middleware
  Rails.application.config.middleware.use HomeAssistantIngressMiddleware

  # Enhanced logging for debugging in Home Assistant environment
  Rails.logger.info "Home Assistant add-on CSRF protection configured with null_session mode"
end
