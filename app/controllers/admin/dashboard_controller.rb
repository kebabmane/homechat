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
    end
  end
end

