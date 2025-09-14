class Api::V1::BaseController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :authenticate_api_request
  
  private
  
  def authenticate_api_request
    token = request.headers['Authorization']&.gsub(/^Bearer /, '')
    
    unless token && valid_api_token?(token)
      render json: { error: 'Unauthorized' }, status: :unauthorized
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
    User.create!(
      username: 'system',
      password: SecureRandom.hex(16),
      password_confirmation: 'ignored',
      role: 'user'
    )
  rescue ActiveRecord::RecordInvalid
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
