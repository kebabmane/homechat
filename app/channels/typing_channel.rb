class TypingChannel < ApplicationCable::Channel
  def subscribed
    channel = find_channel
    return reject unless channel && can_access_channel?(channel)

    stream_from stream_name
    Rails.logger.debug "#{current_user.username} subscribed to typing channel for #{channel.name}"
  end

  def typing(data)
    channel = find_channel
    return unless channel && can_access_channel?(channel)

    # Use the authenticated user's username, not the data provided
    ActionCable.server.broadcast(stream_name, {
      username: current_user.username,
      typing: true,
      timestamp: Time.current.iso8601
    })
  end

  def stop_typing(data)
    channel = find_channel
    return unless channel && can_access_channel?(channel)

    ActionCable.server.broadcast(stream_name, {
      username: current_user.username,
      typing: false,
      timestamp: Time.current.iso8601
    })
  end

  private

  def stream_name
    "typing:#{params[:id]}"
  end

  def find_channel
    @channel ||= Channel.find_by(id: params[:id])
  end

  def can_access_channel?(channel)
    return true if channel.public?
    return true if channel.creator == current_user

    # Check if user is a member of private channels
    channel.members.include?(current_user)
  end
end

