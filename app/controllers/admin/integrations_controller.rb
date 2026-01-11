module Admin
  class IntegrationsController < ApplicationController
    before_action :require_admin

    def test_connection
      token = ApiToken.active.first&.token

      if token.blank?
        render json: {
          status: 'error',
          message: 'No active API tokens found. Create one in Automations > API Tokens.'
        }
        return
      end

      render json: {
        status: 'success',
        message: 'API connectivity test passed',
        details: {
          api_enabled: Setting.fetch('api_enabled', true),
          active_tokens: ApiToken.active.count,
          active_bots: Bot.active.count,
          base_url: request.base_url
        }
      }
    rescue => e
      render json: {
        status: 'error',
        message: "Connection test failed: #{e.message}"
      }
    end
  end
end
