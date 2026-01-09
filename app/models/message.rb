class Message < ApplicationRecord
  MENTION_REGEX = /(?:^|\s)@([A-Za-z0-9_]{3,50})/

  include ActionView::RecordIdentifier
  belongs_to :user
  belongs_to :channel
  has_many_attached :files

  validates :content, presence: true, length: { minimum: 1, maximum: 2000 }
  validate :content_not_blank
  
  scope :recent, -> { order(created_at: :desc) }
  scope :for_channel, ->(channel) { where(channel: channel) }
  
  def author_name
    user.username
  end

  after_create_commit -> { broadcast_append }
  after_create_commit -> { broadcast_to_chat_channel }
  after_create_commit :schedule_ai_bot_responses
  after_create_commit :invite_mentioned_users
  after_create_commit :update_channel_last_message_timestamp

  private

  def content_not_blank
    if content.present? && content.strip.blank?
      errors.add(:content, "cannot be blank")
    end
  end

  def broadcast_append
    broadcast_append_to channel,
      target: dom_id(channel, :messages),
      partial: "messages/message",
      locals: { message: self }
  end

  def broadcast_to_chat_channel
    # Serialize files for broadcast
    file_data = if files.attached?
      files.map do |file|
        {
          id: file.id,
          filename: file.filename.to_s,
          content_type: file.content_type,
          byte_size: file.byte_size,
          url: Rails.application.routes.url_helpers.rails_blob_url(file, only_path: true),
          thumbnail_url: file.image? ? Rails.application.routes.url_helpers.rails_blob_url(file.variant(resize_to_limit: [400, 400]), only_path: true) : nil
        }
      end
    else
      []
    end

    # Broadcast to mobile clients via ChatChannel
    ChatChannel.broadcast_to(channel, {
      type: 'new_message',
      message: {
        id: id,
        content: content,
        user: {
          id: user.id,
          username: user.username,
          role: user.role
        },
        channelId: channel.id,
        createdAt: created_at.iso8601,
        messageType: message_type || 'chat',
        files: file_data
      }
    })
  rescue => e
    Rails.logger.error "Failed to broadcast message to ChatChannel: #{e.message}"
  end

  def schedule_ai_bot_responses
    return if message_type&.start_with?('bot')

    Bots::Dispatcher.new(self).call
  rescue NameError
    Rails.logger.warn('Bots dispatcher not available; skipping bot response')
  end

  def invite_mentioned_users
    return if content.blank?
    return if channel.dm?

    usernames = content.scan(MENTION_REGEX).map do |mention|
      mention.is_a?(Array) ? mention.first.to_s.downcase : mention.to_s.downcase
    end.uniq
    return if usernames.empty?

    mentioned_users = User.where('LOWER(username) IN (?)', usernames)

    mentioned_users.each do |mentioned_user|
      next if mentioned_user.id == user_id
      next if channel.channel_memberships.exists?(user_id: mentioned_user.id)

      channel.channel_memberships.create_with(joined_at: Time.current).find_or_create_by!(user: mentioned_user)
    end
  rescue => e
    Rails.logger.error("Failed to invite mentioned users for message #{id}: #{e.class} #{e.message}")
  end

  def update_channel_last_message_timestamp
    # Update the channel's last_message_at for efficient sorting
    channel.update_column(:last_message_at, created_at)
  rescue => e
    Rails.logger.error("Failed to update channel last_message_at for message #{id}: #{e.class} #{e.message}")
  end
end
