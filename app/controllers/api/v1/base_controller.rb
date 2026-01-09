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

    authenticated_user = token ? ApiToken.valid_token?(token) : false
    unless authenticated_user
      Rails.logger.warn "API Authentication failed - Token: #{token ? 'present but invalid' : 'missing'}"
      render json: { error: 'Unauthorized - Invalid or missing API token' }, status: :unauthorized
    else
      @current_api_user = authenticated_user
      Rails.logger.debug "API Authentication successful for user: #{@current_api_user.username}!" if Rails.env.development?
    end
  end

  def current_api_user
    @current_api_user
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

  # Serialize file attachments for API responses
  def serialize_files(message)
    return [] unless message.files.attached?

    message.files.map do |file|
      {
        id: file.id,
        filename: file.filename.to_s,
        content_type: file.content_type,
        byte_size: file.byte_size,
        url: rails_blob_url(file, host: request.base_url),
        thumbnail_url: file.image? ? rails_blob_url(file.variant(resize_to_limit: [400, 400]), host: request.base_url) : nil
      }
    end
  rescue => e
    Rails.logger.error "Error serializing files: #{e.message}"
    []
  end

  # Helper to serialize a message for API response
  def serialize_message(message)
    {
      id: message.id,
      content: message.content,
      user: {
        id: message.user.id,
        username: message.user.username,
        role: message.user.role,
        created_at: message.user.created_at&.iso8601
      },
      channel_id: message.channel_id,
      created_at: message.created_at.iso8601,
      message_type: message.message_type || 'chat',
      files: serialize_files(message)
    }
  end
end
