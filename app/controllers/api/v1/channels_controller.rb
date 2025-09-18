class Api::V1::ChannelsController < Api::V1::BaseController
  # GET /api/v1/channels
  def index
    user = current_api_user
    channels = Channel.accessible_by(user).includes(members: []).order(:name)
    render json: {
      channels: channels.map do |c|
        {
          id: c.id,
          name: c.name,
          type: c.channel_type,
          members: c.member_count,
          is_member: c.members.include?(user),
          online_members: c.members.where(is_online: true).count
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

    if channel.members.include?(user)
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

