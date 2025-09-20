class Api::V1::SearchController < Api::V1::BaseController
  def index
    query = params[:q]&.strip
    type = params[:type] || 'all' # 'users', 'channels', or 'all'

    if query.blank?
      render_error('Query parameter is required')
      return
    end

    if query.length < 2
      render_error('Query must be at least 2 characters')
      return
    end

    user = current_api_user

    users = search_users(query, user)
    channels = search_channels(query, user)
    messages = search_messages(query, user)

    results = {
      users: users,
      channels: channels,
      messages: messages,
      totalResults: users.length + channels.length + messages.length
    }

    render json: results
  end

  def search_users
    query = params[:q]&.strip

    if query.blank?
      render_error('Query parameter is required')
      return
    end

    if query.length < 2
      render_error('Query must be at least 2 characters')
      return
    end

    user = current_api_user
    users = search_users(query, user)

    render json: { users: users }
  end

  private

  def search_users(query, current_user)
    User.where('LOWER(username) LIKE LOWER(?)', "%#{query}%")
        .where.not(id: current_user.id)
        .limit(10)
        .map do |user|
      {
        id: user.id,
        username: user.username,
        is_online: user.online?,
        status: user.status,
        last_seen_at: user.last_seen_at&.iso8601,
        avatar_url: user.avatar_url,
        avatar_initials: user.avatar_initials,
        avatar_color_index: user.avatar_color_index
      }
    end
  end

  def search_channels(query, current_user)
    Channel.accessible_by(current_user)
           .where('LOWER(name) LIKE LOWER(?) OR LOWER(description) LIKE LOWER(?)', "%#{query}%", "%#{query}%")
           .limit(10)
           .map do |channel|
      {
        id: channel.id,
        name: channel.name,
        type: channel.channel_type,
        description: channel.description,
        members: channel.member_count,
        is_member: channel.members.include?(current_user),
        online_members: channel.members.where(is_online: true).count
      }
    end
  end

  def search_messages(query, current_user)
    # Search messages in channels the user has access to
    accessible_channel_ids = Channel.accessible_by(current_user).pluck(:id)

    Message.joins(:channel)
           .where(channel_id: accessible_channel_ids)
           .where('LOWER(content) LIKE LOWER(?)', "%#{query}%")
           .includes(:user, :channel)
           .order(created_at: :desc)
           .limit(10)
           .map do |message|
      {
        id: message.id,
        content: message.content,
        created_at: message.created_at.iso8601,
        user: {
          id: message.user.id,
          username: message.user.username
        },
        channel: {
          id: message.channel.id,
          name: message.channel.name
        }
      }
    end
  end
end