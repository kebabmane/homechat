class Api::V1::BaseController < ApplicationController
  protect_from_forgery with: :null_session
  skip_before_action :verify_authenticity_token
  before_action :authenticate_api_request
  
  private
  
  def authenticate_api_request
    auth_header = request.headers['Authorization']
    x_api_key = request.headers['X-API-Key']

    # Only log debug info in development
    if Rails.env.development?
      Rails.logger.debug "=== API Authentication Debug ==="
      Rails.logger.debug "Authorization header present: #{auth_header.present?}"
      Rails.logger.debug "X-API-Key header present: #{x_api_key.present?}"
    end

    # Try both Authorization header and X-API-Key header
    token = auth_header&.gsub(/^Bearer /, '') || x_api_key

    unless token && valid_api_token?(token)
      Rails.logger.warn "API Authentication failed - Token: #{token ? 'present but invalid' : 'missing'}"
      render json: { error: 'Unauthorized - Invalid or missing API token' }, status: :unauthorized
    else
      Rails.logger.debug "API Authentication successful!" if Rails.env.development?
    end
  end
  
  def valid_api_token?(token)
    ApiToken.valid_token?(token)
  end
  
  def current_api_user
    # Return a system user for API requests
    @current_api_user ||= User.find_by(username: 'system') || create_system_user
  end
  
  def create_system_user
    password = SecureRandom.hex(16)
    User.create!(
      username: 'system',
      password: password,
      password_confirmation: password,
      role: 'user'
    )
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.warn "Failed to create system user: #{e.message}"
    User.find_by(username: 'system')
  end
  
  def render_error(message, status = :bad_request)
    render json: { error: message }, status: status
  end
  
  def render_success(data = {}, message = nil)
    response = { success: true }
    response[:message] = message if message
    response[:data] = data unless data.empty?
    render json: response
  end

  def ensure_channel_access(channel)
    unless channel.accessible_by?(current_api_user)
      render_error('Unauthorized - No access to this channel', :forbidden)
      return false
    end
    true
  end
end
