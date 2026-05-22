class Api::V1::ChannelsController < Api::V1::BaseController
  # Scope checks for channel operations
  before_action -> { require_scope("user:channels") }
  before_action :require_non_bot_token, only: [ :create, :join, :leave ]

  # POST /api/v1/channels
  def create
    user = current_api_user

    channel = Channel.new(
      name: params[:name],
      description: params[:description],
      channel_type: params[:channel_type] || "public",
      created_by: user
    )

    if channel.save
      # Automatically add creator as member
      channel.add_member(user)

      render_resource(:channel, serialize_channel(channel, user, is_member: true, online_count: 1), status: :created)
    else
      render_model_errors(channel)
    end
  end

  # GET /api/v1/channels
  def index
    user = current_api_user

    channels = Channel
                 .accessible_by(user)
                 .where.not(channel_type: "dm")
                 .order(:name)
                 .load

    channel_ids = channels.map(&:id)

    membership_lookup = if user && channel_ids.any?
      ChannelMembership
        .where(channel_id: channel_ids, user_id: user.id)
        .pluck(:channel_id)
        .index_with { |channel_id| true }
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
        .where("users.updated_at > ?", cutoff)
        .group(:channel_id)
        .count
    end

    member_counts = if channel_ids.empty?
      {}
    else
      ChannelMembership
        .where(channel_id: channel_ids)
        .group(:channel_id)
        .count
    end

    unread_counts = unread_counts_for_user_and_channels(user, channel_ids)

    last_messages = if channel_ids.empty?
      {}
    else
      recent_scope = Message
                       .select("channel_id, MAX(created_at) AS latest_created_at")
                       .where(channel_id: channel_ids)
                       .group(:channel_id)

      Message
        .joins("INNER JOIN (#{recent_scope.to_sql}) AS recent_messages ON recent_messages.channel_id = messages.channel_id AND recent_messages.latest_created_at = messages.created_at")
        .includes(:user)
        .where(channel_id: channel_ids)
        .group_by(&:channel_id)
        .transform_values { |messages| messages.max_by { |message| [ message.created_at, message.id ] } }
    end

    serialized_channels = channels.map do |channel|
      last_message = last_messages[channel.id]
      serialize_channel(
        channel, user,
        is_member: membership_lookup.key?(channel.id),
        online_count: online_counts[channel.id] || 0,
        last_message: last_message,
        member_count: member_counts[channel.id] || 0,
        unread_count: unread_counts[channel.id] || 0
      )
    end

    render_collection(:channels, serialized_channels)
  end

  # POST /api/v1/channels/:id/join
  def join
    channel = Channel.find(params[:id])
    user = current_api_user

    if channel.accessible_by?(user)
      if channel.add_member(user)
        render_success_message("Successfully joined channel")
      else
        render_api_error("Already a member of this channel")
      end
    else
      render_forbidden("Channel not accessible")
    end
  rescue ActiveRecord::RecordNotFound
    render_not_found("Channel")
  end

  # DELETE /api/v1/channels/:id/leave
  def leave
    channel = Channel.find(params[:id])
    user = current_api_user

    if channel.member?(user)
      channel.remove_member(user)
      render_success_message("Successfully left channel")
    else
      render_api_error("Not a member of this channel")
    end
  rescue ActiveRecord::RecordNotFound
    render_not_found("Channel")
  end

  # GET /api/v1/channels/:id/members
  def members
    channel = Channel.find(params[:id])
    user = current_api_user

    return unless ensure_channel_access(channel)

    channel_members = channel.members.includes([]).order(:username)
    serialized_members = channel_members.map { |member| serialize_member(member) }

    render_collection(:members, serialized_members)
  rescue ActiveRecord::RecordNotFound
    render_not_found("Channel")
  end

  # POST /api/v1/channels/:id/mark_as_read
  def mark_as_read
    channel = Channel.find(params[:id])
    user = current_api_user

    membership = channel.channel_memberships.find_by(user: user)

    if membership
      membership.mark_as_read!
      render_success_message("Marked as read", data: { unread_count: 0 })
    else
      render_forbidden("Not a member of this channel")
    end
  rescue ActiveRecord::RecordNotFound
    render_not_found("Channel")
  end

  private

  def serialize_channel(channel, user, is_member: false, online_count: 0, last_message: nil, member_count: nil, unread_count: nil)
    {
      id: channel.id,
      name: channel.name,
      description: channel.description,
      type: channel.channel_type,
      member_count: member_count.nil? ? channel.member_count : member_count,
      online_member_count: online_count,
      last_message: last_message ? serialize_last_message(last_message) : nil,
      unread_count: unread_count.nil? ? channel.unread_count_for(user) : unread_count,
      is_member: is_member,
      created_at: channel.created_at&.iso8601
    }
  end

  def unread_counts_for_user_and_channels(user, channel_ids)
    return {} if user.nil? || channel_ids.empty?

    ChannelMembership
      .where(user_id: user.id, channel_id: channel_ids)
      .joins("INNER JOIN channels ON channels.id = channel_memberships.channel_id")
      .joins("INNER JOIN messages ON messages.channel_id = channel_memberships.channel_id")
      .where.not(messages: { user_id: user.id })
      .where("messages.created_at > COALESCE(channel_memberships.last_read_at, channel_memberships.joined_at, channels.created_at)")
      .group("channel_memberships.channel_id")
      .count("messages.id")
  end

  def serialize_last_message(message)
    {
      id: message.id,
      content: message.transport_content || E2eePolicy::PLACEHOLDER_CONTENT,
      created_at: message.created_at.iso8601,
      user: {
        id: message.user.id,
        username: message.user.username
      }
    }
  end

  def serialize_member(member)
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
end
