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

    results = {}
    user = current_api_user

    case type
    when 'users'
      results[:users] = search_users(query, user)
    when 'channels'
      results[:channels] = search_channels(query, user)
    else # 'all'
      results[:users] = search_users(query, user)
      results[:channels] = search_channels(query, user)
    end

    render json: results
  end

  private

  def search_users(query, current_user)
    User.where('username ILIKE ?', "%#{query}%")
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
           .where('name ILIKE ? OR description ILIKE ?', "%#{query}%", "%#{query}%")
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
end