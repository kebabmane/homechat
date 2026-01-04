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

    users = find_users(query, user)
    channels = find_channels(query, user)
    messages = find_messages(query, user)

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
    users = find_users(query, user)

    render json: { users: users }
  end

  private

  # Sanitize query by escaping SQL wildcards to prevent injection
  def sanitize_search_query(query)
    # Escape SQL LIKE wildcards: % and _
    query.gsub(/[%_]/, '\\\\\0')
  end

  def find_users(query, current_user)
    sanitized_query = sanitize_search_query(query)
    User.where('LOWER(username) LIKE LOWER(?)', "%#{sanitized_query}%")
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

  def find_channels(query, current_user)
    sanitized_query = sanitize_search_query(query)
    channels = Channel.accessible_by(current_user)
                      .where.not(channel_type: 'dm')
                      .where('LOWER(name) LIKE LOWER(?) OR LOWER(description) LIKE LOWER(?)', "%#{sanitized_query}%", "%#{sanitized_query}%")
                      .order(:name)
                      .limit(10)
                      .load

    channel_ids = channels.map(&:id)

    membership_lookup = if current_user && channel_ids.any?
      ChannelMembership
        .where(channel_id: channel_ids, user_id: current_user.id)
        .pluck(:channel_id)
        .each_with_object({}) { |channel_id, memo| memo[channel_id] = true }
    else
      {}
    end

    online_counts = if channel_ids.any?
      cutoff = Time.current - 5.minutes
      ChannelMembership
        .joins(:user)
        .where(channel_id: channel_ids)
        .where('users.updated_at > ?', cutoff)
        .group(:channel_id)
        .count
    else
      {}
    end

    channels.map do |channel|
      {
        id: channel.id,
        name: channel.name,
        type: channel.channel_type,
        description: channel.description,
        members: channel.member_count,
        is_member: membership_lookup.key?(channel.id),
        online_members: online_counts[channel.id] || 0
      }
    end
  end

  def find_messages(query, current_user)
    sanitized_query = sanitize_search_query(query)
    # Search messages in channels the user has access to
    accessible_channels = Channel.accessible_by(current_user).select(:id)

    Message.joins(:channel)
           .where(channel_id: accessible_channels)
           .where('LOWER(content) LIKE LOWER(?)', "%#{sanitized_query}%")
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
