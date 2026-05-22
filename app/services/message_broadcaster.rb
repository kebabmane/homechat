# Service object to handle all message broadcasting and post-creation tasks
# Extracted from Message model to reduce callback complexity
class MessageBroadcaster
  include ActionView::RecordIdentifier

  attr_reader :message

  def initialize(message)
    @message = message
  end

  # Main entry point - performs all post-creation tasks
  def call
    broadcast_to_turbo
    broadcast_to_action_cable
    schedule_bot_responses
    invite_mentioned_users
    schedule_link_preview_fetches
    send_push_notifications
    update_channel_timestamp
  end

  private

  def broadcast_to_turbo
    message.broadcast_append_to message.channel,
      target: dom_id(message.channel, :messages),
      partial: "messages/message",
      locals: { message: message }
  end

  def broadcast_to_action_cable
    return if message.skip_chat_broadcast

    # Serialize files for broadcast
    file_data = if message.files.attached?
      message.files.map do |file|
        {
          id: file.id,
          filename: file.filename.to_s,
          content_type: file.content_type,
          byte_size: file.byte_size,
          url: Rails.application.routes.url_helpers.rails_blob_url(file, only_path: true),
          thumbnail_url: file.image? ? Rails.application.routes.url_helpers.rails_blob_url(file.variant(resize_to_limit: [ 400, 400 ]), only_path: true) : nil
        }
      end
    else
      []
    end

    # Broadcast to mobile clients via explicit stream name for compatibility
    stream_name = "chat_channel_#{message.channel.id}"
    payload = {
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
        message_type: message.message_type || "chat",
        files: file_data,
        receipts: { delivered_count: 0, read_count: 0 }
      }
    }
    Rails.logger.info "[ChatChannel] Broadcasting to #{stream_name}: [content redacted]"
    ActionCable.server.broadcast(stream_name, payload)
  rescue => e
    Rails.logger.error "Failed to broadcast message to ChatChannel: #{e.class}"
    Rails.logger.error e.backtrace.first(5).join("\n")
  end

  def schedule_bot_responses
    return if E2eePolicy.required_for_channel?(message.channel)
    return if message.message_type&.start_with?("bot")

    Bots::Dispatcher.new(message).call
  rescue NameError
    Rails.logger.warn("Bots dispatcher not available; skipping bot response")
  end

  def invite_mentioned_users
    return if E2eePolicy.required_for_channel?(message.channel) && message.e2ee?
    return if message.content.blank?
    return if message.channel.dm?

    usernames = extract_mentioned_usernames
    return if usernames.empty?

    mentioned_users = User.where("LOWER(username) IN (?)", usernames)

    mentioned_users.each do |mentioned_user|
      next if mentioned_user.id == message.user_id
      next if message.channel.channel_memberships.exists?(user_id: mentioned_user.id)

      message.channel.channel_memberships.create_with(joined_at: Time.current).find_or_create_by!(user: mentioned_user)
    end
  rescue => e
    Rails.logger.error("Failed to invite mentioned users for message #{message.id}: #{e.class}")
  end

  def schedule_link_preview_fetches
    return if message.e2ee?
    return if message.content.blank?

    LinkPreviewService.extract_urls(message.content).each do |url|
      next if LinkPreviewService.cached_preview(url).present?

      LinkPreviewFetchJob.perform_later(url)
    end
  rescue => e
    Rails.logger.error("Failed to schedule link previews for message #{message.id}: #{e.class}")
  end

  def send_push_notifications
    return unless FcmNotificationService.fcm_configured?

    # Send regular channel notification (excluding sender) asynchronously
    if message.channel.dm?
      # For DMs, notify the other user
      other_user = message.channel.members.where.not(id: message.user_id).first
      if other_user
        FcmNotificationJob.perform_later(:send_direct_message_notification, message.id,
                                        "recipient_id" => other_user.id)
      end
    else
      # For channels, notify all members except sender
      FcmNotificationJob.perform_later(:send_message_notification, message.id,
                                       "exclude_user_id" => message.user_id)
    end

    # Send mention-specific notifications
    send_mention_notifications
  rescue StandardError => e
    Rails.logger.error("Failed to send push notifications for message #{message.id}: #{e.class}")
  end

  def send_mention_notifications
    return if E2eePolicy.required_for_channel?(message.channel) && message.e2ee?
    return if message.content.blank?

    usernames = extract_mentioned_usernames
    return if usernames.empty?

    mentioned_users = User.where("LOWER(username) IN (?)", usernames)
                          .where.not(id: message.user_id)
                          .where.not(fcm_token: [ nil, "" ])

    mentioned_users.each do |mentioned_user|
      FcmNotificationJob.perform_later(:send_mention_notification, message.id,
                                       "mentioned_user_id" => mentioned_user.id)
    end
  rescue StandardError => e
    Rails.logger.error("Failed to send mention notifications for message #{message.id}: #{e.class}")
  end

  def update_channel_timestamp
    # Update the channel's last_message_at for efficient sorting
    message.channel.update_column(:last_message_at, message.created_at)
  rescue => e
    Rails.logger.error("Failed to update channel last_message_at for message #{message.id}: #{e.class}")
  end

  def extract_mentioned_usernames
    message.content.scan(Message::MENTION_REGEX).map do |mention|
      mention.is_a?(Array) ? mention.first.to_s.downcase : mention.to_s.downcase
    end.uniq
  end
end
