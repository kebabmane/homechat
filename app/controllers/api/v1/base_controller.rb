class Api::V1::BaseController < ApplicationController
  include ApiResponse

  protect_from_forgery with: :null_session
  skip_before_action :verify_authenticity_token
  before_action :authenticate_api_request
  around_action :track_api_timing

  private

  def authenticate_api_request
    auth_header = request.headers["Authorization"]
    x_api_key = request.headers["X-API-Key"]

    # Only log debug info in development
    if Rails.env.development?
      Rails.logger.debug "=== API Authentication Debug ==="
      Rails.logger.debug "Authorization header present: #{auth_header.present?}"
      Rails.logger.debug "X-API-Key header present: #{x_api_key.present?}"
    end

    # Try both Authorization header and X-API-Key header
    token_string = auth_header&.gsub(/^Bearer /, "") || x_api_key

    # valid_token? now returns the ApiToken record (not user) to support scope checking
    @current_api_token = token_string ? ApiToken.valid_token?(token_string) : nil

    if @current_api_token.nil? && allow_session_api_auth?
      session_user = current_user
      if session_user
        @current_api_user = session_user
        return
      end
    end

    unless @current_api_token
      Rails.logger.warn "API Authentication failed - Token: #{token_string ? 'present but invalid' : 'missing'}"
      render json: { error: "Unauthorized - Invalid or missing API token" }, status: :unauthorized
    else
      @current_api_user = @current_api_token.user
      Rails.logger.debug "API Authentication successful for user_id=#{@current_api_user&.id}" if Rails.env.development?
    end
  end

  def current_api_token
    @current_api_token
  end

  def current_api_user
    @current_api_user
  end

  def allow_session_api_auth?
    false
  end

  # Check if the current token has any of the specified scopes
  # Returns true if scope check passes, renders 403 and returns false otherwise
  def require_scope(*scopes)
    return true if current_api_token.nil? # Let authenticate_api_request handle missing token

    unless scopes.any? { |s| current_api_token.has_scope?(s) }
      render json: { error: "Forbidden - Insufficient scope" }, status: :forbidden
      return false
    end
    true
  end

  # Check if the current token can access a channel with the specified action
  # Combines token scope check with user-level access check
  def require_channel_access(channel, action = :read)
    return true if current_api_token.nil?

    # First check token scope
    unless current_api_token.can_access_channel?(channel, action)
      render json: { error: "Forbidden - Token does not have access to this channel" }, status: :forbidden
      return false
    end

    # Then check user-level access
    unless channel.accessible_by?(current_api_user)
      render json: { error: "Forbidden - User cannot access this channel" }, status: :forbidden
      return false
    end

    true
  end

  # Block bot tokens from accessing user data endpoints
  def require_non_bot_token
    return true if current_api_token.nil?

    if current_api_token.bot_token?
      render json: { error: "Forbidden - Bot tokens cannot access user data" }, status: :forbidden
      return false
    end
    true
  end

  def create_system_user
    password = SecureRandom.hex(16)
    User.create!(
      username: "system",
      password: password,
      password_confirmation: password,
      role: "user"
    )
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.warn "Failed to create system user: #{e.class}"
    User.find_by(username: "system")
  end

  # Legacy helper - delegates to ApiResponse concern
  # Kept for backward compatibility with existing code
  def render_error(message, status = :bad_request)
    render_api_error(message, status: status)
  end

  # Legacy helper - delegates to ApiResponse concern
  # Kept for backward compatibility with existing code
  def render_success(data = {}, message = nil)
    if message.present? && data.empty?
      render_success_message(message)
    elsif message.present?
      render_success_message(message, data: data)
    elsif data.empty?
      render json: { success: true }
    else
      render_data(data)
    end
  end

  # Legacy method - now uses scope-aware channel access check
  def ensure_channel_access(channel)
    require_channel_access(channel, :read)
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
        thumbnail_url: file.image? ? rails_blob_url(file.variant(resize_to_limit: [ 400, 400 ]), host: request.base_url) : nil
      }
    end
  rescue => e
    Rails.logger.error "Error serializing files: #{e.class}"
    []
  end

  # Helper to serialize a message for API response
  def serialize_message(message)
    receipts = message.message_receipts
    delivered_count, read_count = receipt_status_counts(receipts)

    {
      id: message.id,
      content: message.transport_content,
      user: {
        id: message.user.id,
        username: message.user.username,
        role: message.user.role,
        created_at: message.user.created_at&.iso8601
      },
      channel_id: message.channel_id,
      created_at: message.created_at.iso8601,
      message_type: message.message_type || "chat",
      files: serialize_files(message),
      content_hmac: message.content_hmac,
      content_encoding: message.content_encoding || "plaintext",
      encrypted_content: message.encrypted_content,
      sender_device_id: message.respond_to?(:sender_device_id) ? message.sender_device_id : nil,
      sender_key_fingerprint: message.respond_to?(:sender_key_fingerprint) ? message.sender_key_fingerprint : nil,
      e2ee_version: message.respond_to?(:e2ee_version) ? message.e2ee_version : nil,
      receipts: {
        delivered_count: delivered_count,
        read_count: read_count
      }
    }
  end

  def receipt_status_counts(receipts)
    if receipts.loaded?
      delivered_status = MessageReceipt.statuses["delivered"]
      read_status = MessageReceipt.statuses["read"]

      delivered_count = 0
      read_count = 0
      receipts.each do |receipt|
        delivered_count += 1 if receipt.status_before_type_cast == delivered_status
        read_count += 1 if receipt.status_before_type_cast == read_status
      end
      [ delivered_count, read_count ]
    else
      [
        receipts.where(status: MessageReceipt.statuses[:delivered]).count,
        receipts.where(status: MessageReceipt.statuses[:read]).count
      ]
    end
  end

  def track_api_timing
    return yield unless request.path.start_with?("/api/")

    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    sql_count = 0

    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |_name, _start, _finish, _id, payload|
      next if payload[:cached] || payload[:name] == "SCHEMA"

      sql_count += 1
    end

    yield
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber

    if started_at
      duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000.0).round(1)
      log_level = duration_ms >= 300.0 ? :info : :debug
      Rails.logger.public_send(
        log_level,
        "API timing action=#{controller_name}##{action_name} method=#{request.request_method} path=#{request.path} status=#{response.status} duration_ms=#{duration_ms} sql_count=#{sql_count}"
      )
    end
  end
end
