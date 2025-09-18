class PresenceChannel < ApplicationCable::Channel
  def subscribed
    stream_from "presence"
    current_user&.mark_online!
  end

  def unsubscribed
    current_user&.mark_offline!
  end

  def heartbeat
    current_user&.update_presence!
  end

  def set_status(data)
    status = data['status']
    current_user&.set_status!(status) if status.present?
  end

  def typing(data)
    channel_id = data['channel_id']
    return unless channel_id.present? && current_user

    # Broadcast typing event to specific channel
    ActionCable.server.broadcast("channel_#{channel_id}", {
      type: 'typing',
      user: {
        id: current_user.id,
        username: current_user.username
      },
      timestamp: Time.current.iso8601
    })
  end

  def stop_typing(data)
    channel_id = data['channel_id']
    return unless channel_id.present? && current_user

    # Broadcast stop typing event to specific channel
    ActionCable.server.broadcast("channel_#{channel_id}", {
      type: 'stop_typing',
      user: {
        id: current_user.id,
        username: current_user.username
      },
      timestamp: Time.current.iso8601
    })
  end
end
