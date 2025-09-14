module Admin
  class DashboardController < ApplicationController
    before_action :require_admin

    def index
      @token_count = ApiToken.count
      @active_token_count = ApiToken.active.count
      @last_token_use = ApiToken.maximum(:last_used_at)
      @bots_active = Bot.active.count
      @bots_total = Bot.count
      @api_enabled = Setting.fetch('api_enabled', true)
      @ha_enabled = Setting.fetch('home_assistant_enabled', true)
      @webhook_base = Setting.fetch('webhook_base_url', request.base_url)

      # Check for admin credentials file
      @admin_credentials_available = File.exist?(Rails.env.production? ? '/data/admin_credentials.json' : 'tmp/admin_credentials.json')
    end

    def admin_credentials
      credentials_file = Rails.env.production? ? '/data/admin_credentials.json' : 'tmp/admin_credentials.json'

      if File.exist?(credentials_file)
        @credentials = JSON.parse(File.read(credentials_file))
        render json: {
          success: true,
          credentials: @credentials,
          note: "These are the default admin credentials created during first startup. Please change your password after logging in."
        }
      else
        render json: {
          success: false,
          message: "No admin credentials file found. This usually means an admin user was created manually or the system has been reset."
        }
      end
    end
  end
end

