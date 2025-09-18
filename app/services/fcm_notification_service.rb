class FcmNotificationService
  def self.send_message_notification(message, exclude_user: nil)
    # Get all users in the channel with FCM tokens, excluding the sender
    channel_users = message.channel.members
                           .where.not(fcm_token: nil)
                           .where.not(fcm_token: '')

    channel_users = channel_users.where.not(id: exclude_user.id) if exclude_user

    if channel_users.empty?
      Rails.logger.info "No users with FCM tokens found for channel #{message.channel.name}"
      return
    end

    fcm_tokens = channel_users.pluck(:fcm_token)

    # Prepare notification payload
    notification_data = {
      title: "#{message.channel.name}",
      body: "#{message.user.username}: #{truncate_message(message.content)}",
      data: {
        type: 'new_message',
        channel_id: message.channel.id.to_s,
        message_id: message.id.to_s,
        username: message.user.username,
        content: message.content,
        channel_name: message.channel.name
      }
    }

    # Send notification
    send_to_tokens(fcm_tokens, notification_data)
  end

  def self.send_channel_invite_notification(user, channel, inviter)
    return if user.fcm_token.blank?

    notification_data = {
      title: "Channel Invitation",
      body: "#{inviter.username} invited you to join #{channel.name}",
      data: {
        type: 'channel_invite',
        channel_id: channel.id.to_s,
        channel_name: channel.name,
        inviter: inviter.username
      }
    }

    send_to_tokens([user.fcm_token], notification_data)
  end

  def self.send_direct_message_notification(message, recipient)
    return if recipient.fcm_token.blank?

    notification_data = {
      title: "#{message.user.username}",
      body: truncate_message(message.content),
      data: {
        type: 'direct_message',
        channel_id: message.channel.id.to_s,
        message_id: message.id.to_s,
        username: message.user.username,
        content: message.content
      }
    }

    send_to_tokens([recipient.fcm_token], notification_data)
  end

  private

  def self.send_to_tokens(tokens, notification_data)
    return if tokens.empty?

    # For now, just log what we would send
    # In a real implementation, you would use the Firebase Admin SDK
    Rails.logger.info "Would send FCM notification to #{tokens.length} device(s):"
    Rails.logger.info "Title: #{notification_data[:title]}"
    Rails.logger.info "Body: #{notification_data[:body]}"
    Rails.logger.info "Data: #{notification_data[:data]}"
    Rails.logger.info "Tokens: #{tokens.join(', ')}"

    # TODO: Implement actual FCM sending using Firebase Admin SDK
    # Example with firebase-admin gem:
    # fcm_client = Firebase::Admin::Messaging::Client.new
    #
    # tokens.each do |token|
    #   message = Firebase::Admin::Messaging::Message.new(
    #     token: token,
    #     notification: Firebase::Admin::Messaging::Notification.new(
    #       title: notification_data[:title],
    #       body: notification_data[:body]
    #     ),
    #     data: notification_data[:data].transform_values(&:to_s)
    #   )
    #
    #   begin
    #     response = fcm_client.send(message)
    #     Rails.logger.info "FCM notification sent successfully: #{response}"
    #   rescue => e
    #     Rails.logger.error "Failed to send FCM notification: #{e.message}"
    #   end
    # end

  rescue StandardError => e
    Rails.logger.error "Error sending FCM notifications: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end

  def self.truncate_message(content, length = 100)
    if content.length > length
      "#{content[0..length-4]}..."
    else
      content
    end
  end
end