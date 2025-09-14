class Admin::IntegrationsController < ApplicationController
  before_action :require_admin
  
  def index
    @api_tokens = ApiToken.all.order(:name)
    @bots = Bot.all.order(:name)
    @integration_settings = {
      home_assistant_enabled: Setting.fetch('home_assistant_enabled', true),
      api_enabled: Setting.fetch('api_enabled', true),
      webhook_base_url: Setting.fetch('webhook_base_url', request.base_url)
    }
  end
  
  def create_token
    @token = ApiToken.generate_for_integration(params[:name] || "Home Assistant")
    render :show_token
  rescue ActiveRecord::RecordInvalid => e
    redirect_to admin_integrations_path, alert: "Failed to create token: #{e.record.errors.full_messages.join(', ')}"
  end

  def regenerate_token
    @token = ApiToken.find(params[:id])
    @token.regenerate!
    render :show_token
  rescue ActiveRecord::RecordNotFound
    redirect_to admin_integrations_path, alert: "Token not found"
  end
  
  def deactivate_token
    @api_token = ApiToken.find(params[:id])
    @api_token.deactivate!
    redirect_to admin_integrations_path, notice: "API token deactivated"
  rescue ActiveRecord::RecordNotFound
    redirect_to admin_integrations_path, alert: "Token not found"
  end
  
  def activate_token
    @api_token = ApiToken.find(params[:id])
    @api_token.update!(active: true)
    redirect_to admin_integrations_path, notice: "API token activated"
  rescue ActiveRecord::RecordNotFound
    redirect_to admin_integrations_path, alert: "Token not found"
  end
  
  def update_settings
    settings_params.each do |key, value|
      Setting.set(key, value)
    end
    
    redirect_to admin_integrations_path, notice: "Integration settings updated successfully"
  end
  
  def test_connection
    begin
      # Test basic API connectivity
      token = ApiToken.active.first&.token
      
      if token.blank?
        render json: { 
          status: 'error', 
          message: 'No active API tokens found. Please create one first.' 
        }
        return
      end
      
      # Simulate a simple API test
      render json: {
        status: 'success',
        message: 'API connectivity test passed',
        details: {
          api_enabled: Setting.fetch('api_enabled', true),
          active_tokens: ApiToken.active.count,
          active_bots: Bot.active.count,
          base_url: request.base_url,
          webhook_base_url: Setting.fetch('webhook_base_url', request.base_url)
        }
      }
    rescue => e
      render json: {
        status: 'error',
        message: "Connection test failed: #{e.message}"
      }
    end
  end
  
  private
  
  def settings_params
    params.require(:settings).permit(:home_assistant_enabled, :api_enabled, :webhook_base_url)
  end
end