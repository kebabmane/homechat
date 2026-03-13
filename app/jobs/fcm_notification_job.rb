class FcmNotificationJob < ApplicationJob
  queue_as :default

  # action is one of: :send_message_notification, :send_direct_message_notification,
  #                   :send_mention_notification
  def perform(action, message_id, options = {})
    message = Message.find_by(id: message_id)
    return unless message
    return unless FcmNotificationService.fcm_configured?

    case action.to_sym
    when :send_message_notification
      exclude_user_id = options['exclude_user_id'] || options[:exclude_user_id]
      exclude_user = User.find_by(id: exclude_user_id) if exclude_user_id
      FcmNotificationService.send_message_notification(message, exclude_user: exclude_user)
    when :send_direct_message_notification
      recipient_id = options['recipient_id'] || options[:recipient_id]
      recipient = User.find_by(id: recipient_id)
      FcmNotificationService.send_direct_message_notification(message, recipient) if recipient
    when :send_mention_notification
      mentioned_user_id = options['mentioned_user_id'] || options[:mentioned_user_id]
      mentioned_user = User.find_by(id: mentioned_user_id)
      FcmNotificationService.send_mention_notification(message, mentioned_user) if mentioned_user
    else
      Rails.logger.warn "FcmNotificationJob: Unknown action '#{action}'"
    end
  rescue StandardError => e
    Rails.logger.error "FcmNotificationJob failed for action=#{action} message_id=#{message_id}: #{e.class} #{e.message}"
    raise
  end
end
