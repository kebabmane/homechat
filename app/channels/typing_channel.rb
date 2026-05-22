class TypingChannel < ApplicationCable::Channel
  include RateLimited

  rate_limit :typing, :stop_typing, max: 1, period: 1

  def subscribed
    channel = find_channel
    return reject unless channel && can_access_channel?(channel)

    stream_from stream_name
    Rails.logger.debug "User id=#{current_user.id} subscribed to typing channel_id=#{channel.id}"
  end

  def typing(data)
    channel = find_channel
    return unless channel && can_access_channel?(channel)

    typing_flag = data.key?("typing") ? ActiveModel::Type::Boolean.new.cast(data["typing"]) : true

    # Use the authenticated user's username, not the data provided
    ActionCable.server.broadcast(stream_name, {
      username: current_user.username,
      typing: typing_flag,
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
    channel.member?(current_user)
  end
end
