require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_mailbox/engine"
require "action_text/engine"
require "action_view/railtie"
require "action_cable/engine"
# require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Homechat
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Don't generate system test files.
    config.generators.system_tests = nil

    # Discovery service configuration
    config.discovery = ActiveSupport::OrderedOptions.new
    config.discovery.enabled = ENV.fetch('DISCOVERY_ENABLED', 'true') == 'true'
    config.discovery.server_name = ENV['DISCOVERY_SERVER_NAME']
    config.discovery.port = ENV['DISCOVERY_PORT']&.to_i

    # Home Assistant add-on configuration
    if ENV['HOME_ASSISTANT_ADDON'] == 'true'
      # Configure for Home Assistant ingress environment
      config.force_ssl = false  # SSL termination handled by HA ingress

      # Allow iframe embedding in Home Assistant
      config.action_dispatch.default_headers['X-Frame-Options'] = 'ALLOWALL'

      # Clear host restrictions when behind HA ingress
      config.hosts.clear

      # Disable origin checking for CSRF in HA environment
      # This is safe because we're in a controlled home environment
      config.action_controller.forgery_protection_origin_check = false

      # Use broad trusted proxies for Home Assistant environment
      # Dynamic detection will be done later during initialization
      config.action_dispatch.trusted_proxies = [
        ActionDispatch::RemoteIp::TRUSTED_PROXIES,
        IPAddr.new('172.30.0.0/16'),   # Home Assistant Docker networks
        IPAddr.new('192.168.0.0/16'),  # Common home network range
        IPAddr.new('10.0.0.0/8'),      # Private network range
        IPAddr.new('172.16.0.0/12'),   # Private network range
        IPAddr.new('127.0.0.1'),       # Localhost
        IPAddr.new('::1')              # IPv6 localhost
      ].flatten
    end

    # Session configuration
    config.session_store :cookie_store,
      key: '_homechat_session',
      expire_after: 30.days,
      secure: ENV['HOME_ASSISTANT_ADDON'] == 'true' ? false : Rails.env.production?,
      httponly: true,
      same_site: ENV['HOME_ASSISTANT_ADDON'] == 'true' ? :none : :lax
  end
end
