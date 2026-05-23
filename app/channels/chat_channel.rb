class ChatChannel < ApplicationCable::Channel
  include RateLimited

  rate_limit :speak, max: 10, period: 1

  def subscribed
    channel_id = params[:channel_id]
    return reject unless channel_id

    @channel = Channel.find_by(id: channel_id)
    return reject unless @channel

    # Verify user has access to this channel
    unless channel_accessible?
      reject
      return
    end

    # Use explicit stream name for mobile client compatibility
    # (stream_for uses GlobalID which can cause routing issues)
    stream_name = "chat_channel_#{@channel.id}"
    stream_from stream_name
    Rails.logger.info "User id=#{current_user.id} subscribed to chat_channel_id=#{@channel.id}"

    # L5: Capture token ID for periodic re-validation in speak/receipt
    @api_token_id = connection.current_api_token_id
    @last_token_check = Time.current
  end

  def unsubscribed
    if @channel
      Rails.logger.info "User id=#{current_user.id} unsubscribed from chat_channel_id=#{@channel.id}"
    end
  end

  def speak(data)
    return unless @channel
    return unless channel_accessible?

    # L5: Periodic token re-validation — reject connections that use a revoked token.
    # Checked at most once every 30 minutes to avoid per-message DB hits.
    if @api_token_id && Time.current - (@last_token_check || Time.current) > 30.minutes
      token_record = ApiToken.find_by(id: @api_token_id)
      if token_record.nil? || !token_record.active? || token_record.expired?
        transmit({ type: "auth_expired" })
        reject
        return
      end
      @last_token_check = Time.current
    end

    if E2eePolicy.required_for_channel?(@channel)
      unless E2eePolicy.valid_e2ee_headers?(params: data)
        transmit({ type: "error", code: E2eePolicy::LEGACY_UPGRADE_ERROR_CODE, message: E2eePolicy.e2ee_required_error[:message] })
        return
      end

      unless E2eePolicy.valid_e2ee_payload?(data)
        transmit({ type: "error", code: E2eePolicy::LEGACY_UPGRADE_ERROR_CODE, message: E2eePolicy.e2ee_required_error[:message] })
        return
      end

      if (error = E2eePolicy.validate_sender_device(user: current_user, payload: data))
        transmit({ type: "error", code: error[:code], message: error[:message] })
        return
      end
    end

    content = data["message"]
    return if content.blank? && !E2eePolicy.required_for_channel?(@channel)

    message_attributes = {
      content: content.to_s,
      user: current_user
    }

    if E2eePolicy.required_for_channel?(@channel)
      message_attributes.merge!(
        content_encoding: E2eePolicy::REQUIRED_ENCODING,
        encrypted_content: data["encrypted_content"],
        content_hmac: data["content_hmac"],
        sender_device_id: E2eePolicy.device_id_from(params: data),
        sender_key_fingerprint: data["sender_key_fingerprint"],
        e2ee_version: E2eePolicy.e2ee_version_from(params: data)
      )
    end

    message = @channel.messages.build(message_attributes)

    if message.save
      # Broadcast to all subscribers of this channel using explicit stream name
      ActionCable.server.broadcast("chat_channel_#{@channel.id}", {
        type: "new_message",
        message: {
          id: message.id,
          content: message.transport_content,
          content_encoding: message.content_encoding || "plaintext",
          encrypted_content: message.encrypted_content,
          content_hmac: message.content_hmac,
          sender_device_id: message.respond_to?(:sender_device_id) ? message.sender_device_id : nil,
          sender_key_fingerprint: message.respond_to?(:sender_key_fingerprint) ? message.sender_key_fingerprint : nil,
          e2ee_version: message.respond_to?(:e2ee_version) ? message.e2ee_version : nil,
          user: {
            id: message.user.id,
            username: message.user.username,
            role: message.user.role
          },
          channel_id: message.channel.id,
          created_at: message.created_at.iso8601,
          message_type: "chat",
          files: []
        }
      })
    end
  end

  def receipt(data)
    return unless @channel
    return unless channel_accessible?

    message_id = data["message_id"]&.to_i
    status     = data["status"]
    return unless message_id.present? && %w[delivered read].include?(status)

    message = Message.find_by(id: message_id)
    return unless message&.channel_id == @channel.id

    receipt = MessageReceipt.find_or_initialize_by(message_id: message_id, user: current_user)
    # Only upgrade status: delivered → read
    if receipt.new_record? || MessageReceipt.statuses[status] > MessageReceipt.statuses[receipt.status]
      receipt.status = status
      receipt.save!
    end

    ActionCable.server.broadcast("chat_channel_#{@channel.id}", {
      type: "receipt",
      message_id: message_id,
      user_id: current_user.id,
      status: status
    })
  rescue => e
    Rails.logger.error "ChatChannel#receipt error: #{e.class}"
  end

  private

  def channel_accessible?
    return true if @channel.public?

    # For private channels, check membership
    current_user.member_of?(@channel)
  end
end
