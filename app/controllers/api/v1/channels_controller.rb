class Api::V1::ChannelsController < Api::V1::BaseController
  # Scope checks for channel operations
  before_action -> { require_scope('user:channels') }
  before_action :require_non_bot_token, only: [:create, :join, :leave]

  # POST /api/v1/channels
  def create
    user = current_api_user

    channel = Channel.new(
      name: params[:name],
      description: params[:description],
      channel_type: params[:channel_type] || 'public',
      created_by: user
    )

    if channel.save
      # Automatically add creator as member
      channel.add_member(user)

      render json: {
        success: true,
        channel: {
          id: channel.id,
          name: channel.name,
          description: channel.description,
          type: channel.channel_type,
          member_count: channel.member_count,
          online_member_count: 1,
          is_member: true,
          created_at: channel.created_at&.iso8601
        }
      }, status: :created
    else
      render json: {
        success: false,
        error: channel.errors.full_messages.join(', ')
      }, status: :unprocessable_entity
    end
  end

  # GET /api/v1/channels
  def index
    user = current_api_user

    channels = Channel
                 .accessible_by(user)
                 .where.not(channel_type: 'dm')
                 .order(:name)
                 .load

    channel_ids = channels.map(&:id)

    membership_lookup = if user && channel_ids.any?
      ChannelMembership
        .where(channel_id: channel_ids, user_id: user.id)
        .pluck(:channel_id)
        .each_with_object({}) { |channel_id, memo| memo[channel_id] = true }
    else
      {}
    end

    online_counts = if channel_ids.empty?
      {}
    else
      cutoff = Time.current - 5.minutes
      ChannelMembership
        .joins(:user)
        .where(channel_id: channel_ids)
        .where('users.updated_at > ?', cutoff)
        .group(:channel_id)
        .count
    end

    last_messages = if channel_ids.empty?
      {}
    else
      recent_scope = Message
                       .select('channel_id, MAX(created_at) AS latest_created_at')
                       .where(channel_id: channel_ids)
                       .group(:channel_id)

      Message
        .joins("INNER JOIN (#{recent_scope.to_sql}) AS recent_messages ON recent_messages.channel_id = messages.channel_id AND recent_messages.latest_created_at = messages.created_at")
        .includes(:user)
        .where(channel_id: channel_ids)
        .group_by(&:channel_id)
    end

    render json: {
      channels: channels.map do |channel|
        last_message = last_messages.fetch(channel.id, []).first

        {
          id: channel.id,
          name: channel.name,
          description: channel.description,
          type: channel.channel_type,
          member_count: channel.member_count,
          online_member_count: online_counts[channel.id] || 0,
          last_message: last_message ? {
            id: last_message.id,
            content: last_message.content,
            created_at: last_message.created_at.iso8601,
            user: {
              id: last_message.user.id,
              username: last_message.user.username
            }
          } : nil,
          unread_count: 0, # TODO: Implement unread tracking
          is_member: membership_lookup.key?(channel.id),
          created_at: channel.created_at&.iso8601
        }
      end
    }
  end

  # POST /api/v1/channels/:id/join
  def join
    channel = Channel.find(params[:id])
    user = current_api_user

    if channel.accessible_by?(user)
      if channel.add_member(user)
        render_success({ message: 'Successfully joined channel' })
      else
        render_error('Already a member of this channel')
      end
    else
      render_error('Channel not accessible', :forbidden)
    end
  rescue ActiveRecord::RecordNotFound
    render_error('Channel not found', :not_found)
  end

  # DELETE /api/v1/channels/:id/leave
  def leave
    channel = Channel.find(params[:id])
    user = current_api_user

    if channel.member?(user)
      channel.remove_member(user)
      render_success({ message: 'Successfully left channel' })
    else
      render_error('Not a member of this channel')
    end
  rescue ActiveRecord::RecordNotFound
    render_error('Channel not found', :not_found)
  end

  # GET /api/v1/channels/:id/members
  def members
    channel = Channel.find(params[:id])
    user = current_api_user

    return unless ensure_channel_access(channel)

    members = channel.members.includes([]).order(:username)
    render json: {
      members: members.map do |member|
        {
          id: member.id,
          username: member.username,
          is_online: member.online?,
          status: member.status,
          last_seen_at: member.last_seen_at&.iso8601,
          avatar_url: member.avatar_url,
          avatar_initials: member.avatar_initials,
          avatar_color_index: member.avatar_color_index
        }
      end
    }
  rescue ActiveRecord::RecordNotFound
    render_error('Channel not found', :not_found)
  end
end
