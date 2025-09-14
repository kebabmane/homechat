class Api::V1::BaseController < ApplicationController
  protect_from_forgery with: :null_session
  skip_before_action :verify_authenticity_token
  before_action :authenticate_api_request
  
  private
  
  def authenticate_api_request
    # Log all headers for debugging
    auth_header = request.headers['Authorization']
    x_api_key = request.headers['X-API-Key']

    Rails.logger.info "=== API Authentication Debug ==="
    Rails.logger.info "All headers: #{request.headers.to_h.select { |k, v| k.start_with?('HTTP_') || k.include?('AUTH') || k.include?('API') }}"
    Rails.logger.info "Authorization header: #{auth_header}"
    Rails.logger.info "X-API-Key header: #{x_api_key}"

    # Try both Authorization header and X-API-Key header
    token = auth_header&.gsub(/^Bearer /, '') || x_api_key

    Rails.logger.info "Extracted token present: #{!token.blank?}, Token prefix: #{token&.first(8)}..."

    unless token && valid_api_token?(token)
      Rails.logger.warn "API Authentication failed - Token: #{token ? 'present but invalid' : 'missing'}"
      Rails.logger.warn "Valid tokens available: #{ApiToken.active.count}"
      render json: { error: 'Unauthorized - Invalid or missing API token' }, status: :unauthorized
    else
      Rails.logger.info "API Authentication successful!"
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
end
