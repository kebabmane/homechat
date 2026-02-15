class ChatChannel < ApplicationCable::Channel
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
    Rails.logger.info "User #{current_user.username} subscribed to stream: #{stream_name}"
  end

  def unsubscribed
    if @channel
      Rails.logger.info "User #{current_user.username} unsubscribed from chat channel #{@channel.name}"
    end
  end

  def speak(data)
    return unless @channel
    return unless channel_accessible?

    content = data['message']
    return if content.blank?

    message = @channel.messages.build(
      content: content,
      user: current_user
    )

    if message.save
      # Broadcast to all subscribers of this channel using explicit stream name
      ActionCable.server.broadcast("chat_channel_#{@channel.id}", {
        type: 'new_message',
        message: {
          id: message.id,
          content: message.content,
          user: {
            id: message.user.id,
            username: message.user.username,
            role: message.user.role
          },
          channelId: message.channel.id,
          createdAt: message.created_at.iso8601,
          messageType: 'chat',
          files: []
        }
      })
    end
  end

  private

  def channel_accessible?
    return true if @channel.public?

    # For private channels, check membership
    current_user.member_of?(@channel)
  end
end