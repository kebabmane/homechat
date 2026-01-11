class Api::V1::MessagesController < Api::V1::BaseController
  # Scope checks for message operations
  # Bot tokens can post via create action but cannot access DMs or delete
  before_action :require_message_read_scope, only: [:index, :dm_channels]
  before_action :require_message_write_scope, only: [:create, :create_for_channel, :create_media]
  before_action :require_non_bot_for_dm, only: [:create_dm, :dm_channels, :start_dm_by_username]
  before_action :require_non_bot_for_delete, only: [:destroy]

  # DELETE /api/v1/messages/:id
  def destroy
    message = Message.find(params[:id])
    user = current_api_user

    # Only allow users to delete their own messages (or admins)
    if message.user == user || user.admin?
      channel = message.channel

      # Broadcast deletion to channel subscribers
      ActionCable.server.broadcast(
        "channel_#{channel.id}",
        {
          type: 'message_deleted',
          message_id: message.id
        }
      )

      message.destroy
      render json: { success: true, message: 'Message deleted' }
    else
      render json: { success: false, error: 'You can only delete your own messages' }, status: :forbidden
    end
  rescue ActiveRecord::RecordNotFound
    render json: { success: false, error: 'Message not found' }, status: :not_found
  end

  def create
    begin
      message_params = params.require(:message)
      room_id = params[:room_id]
      user_id = params[:user_id]
      title = params[:title]
      sender = params[:sender] || 'Home Assistant'
      
      # Find or create the channel
      channel = find_or_create_channel(room_id)
      
      # Find the user (or use system user)
      user = user_id ? User.find_by(id: user_id) : current_api_user
      user ||= current_api_user
      
      # Create the message
      message = channel.messages.build(
        user: user,
        content: format_message_content(message_params, title, sender),
        message_type: 'api'
      )
      
      if message.save
        # Broadcast the message to the channel (for Turbo Streams web clients)
        broadcast_message(message, channel)

        # Note: FCM push notifications are now sent via model callback (send_push_notifications)

        render_success({
          message: {
            id: message.id,
            content: message.content,
            user: message.user.username,
            channel: channel.name,
            created_at: message.created_at.iso8601
          }
        }, 'Message sent successfully')
      else
        render_error("Failed to create message: #{message.errors.full_messages.join(', ')}")
      end
      
    rescue ActionController::ParameterMissing => e
      render_error("Missing required parameter: #{e.param}")
    rescue StandardError => e
      Rails.logger.error "API Message Creation Error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      render_error("Internal server error", :internal_server_error)
    end
  end
  
  def index
    channel_id = params[:channel_id]
    limit = [params[:limit]&.to_i || 50, 100].min

    begin
      messages = if channel_id
        channel = Channel.find(channel_id)
        return unless ensure_channel_access(channel)

        channel.messages
               .includes(:user)
               .order(created_at: :desc)
               .limit(limit + 1)
               .to_a
      else
        accessible_channels = Channel.accessible_by(current_api_user).select(:id)

        Message.includes(:user, :channel)
               .where(channel_id: accessible_channels)
               .order(created_at: :desc)
               .limit(limit + 1)
               .to_a
      end

      has_more = messages.length > limit
      messages = messages.first(limit)

      render json: {
        messages: messages.map { |message| serialize_message(message) },
        has_more: has_more
      }
      
    rescue ActiveRecord::RecordNotFound
      render_error("Channel not found", :not_found)
    rescue StandardError => e
      Rails.logger.error "API Message Index Error: #{e.message}"
      render_error("Internal server error", :internal_server_error)
    end
  end
  
  private
  
  def find_or_create_channel(room_id)
    Rails.logger.info "Finding/creating channel for room_id: #{room_id}"
    Rails.logger.info "Current API user: #{current_api_user&.username} (ID: #{current_api_user&.id})"

    if room_id.present?
      # Try to find existing channel by name first
      channel = Channel.find_by(name: room_id)
      if channel
        Rails.logger.info "Found existing channel: #{channel.name} (ID: #{channel.id})"
        return channel
      end

      # Create new channel
      api_user = current_api_user
      unless api_user
        Rails.logger.error "No API user available for channel creation"
        raise "System user not available"
      end

      channel = Channel.create!(
        name: room_id,
        description: "Auto-created channel for Home Assistant integration",
        channel_type: 'public',
        created_by: api_user
      )

      Rails.logger.info "Created new channel: #{channel.name} (ID: #{channel.id})"
      channel
    else
      # Use default channels in order of preference
      channel = Channel.find_by(name: 'home') ||
                Channel.find_by(name: 'general') ||
                Channel.find_by(name: 'home-assistant')

      if channel
        Rails.logger.info "Using default channel: #{channel.name} (ID: #{channel.id})"
        return channel
      end

      # Create home-assistant channel if no defaults exist
      api_user = current_api_user
      unless api_user
        Rails.logger.error "No API user available for default channel creation"
        raise "System user not available"
      end

      channel = Channel.create!(
        name: 'home-assistant',
        description: 'Home Assistant notifications and messages',
        channel_type: 'public',
        created_by: api_user
      )

      Rails.logger.info "Created default home-assistant channel: #{channel.name} (ID: #{channel.id})"
      channel
    end
  rescue => e
    Rails.logger.error "Failed to find/create channel: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise
  end
  
  def format_message_content(message, title, sender)
    content = message.to_s
    
    if title.present?
      content = "**#{title}**\n#{content}"
    end
    
    if sender != 'Home Assistant'
      content = "#{content}\n\n_From: #{sender}_"
    end
    
    content
  end
  
  def broadcast_message(message, channel)
    # Serialize files for broadcast
    files = if message.files.attached?
      message.files.map do |file|
        {
          id: file.id,
          filename: file.filename.to_s,
          content_type: file.content_type,
          byte_size: file.byte_size,
          url: Rails.application.routes.url_helpers.rails_blob_url(file, host: request.base_url),
          thumbnail_url: file.image? ? Rails.application.routes.url_helpers.rails_blob_url(file.variant(resize_to_limit: [400, 400]), host: request.base_url) : nil
        }
      end
    else
      []
    end

    # Broadcast to the channel using ActionCable
    ActionCable.server.broadcast(
      "channel_#{channel.id}",
      {
        type: 'new_message',
        message: {
          id: message.id,
          content: message.content,
          user: {
            id: message.user.id,
            username: message.user.username,
            avatar_url: message.user.avatar_url,
            avatar_initials: message.user.avatar_initials,
            avatar_color_index: message.user.avatar_color_index
          },
          created_at: message.created_at.iso8601,
          message_type: message.message_type,
          files: files
        }
      }
    )
  rescue => e
    Rails.logger.error "Failed to broadcast message: #{e.message}"
  end

  # === New scoped endpoints ===
  public

  # POST /api/v1/channels/:id/messages
  def create_for_channel
    channel = Channel.find(params[:id])
    return unless ensure_channel_access(channel)

    user = current_api_user

    # Support both direct message parameter and CreateMessageRequest format
    content = params[:message]
    message_type = params[:message_type] || 'chat'

    message = channel.messages.build(
      user: user,
      content: content,
      message_type: message_type
    )

    if message.save
      broadcast_message(message, channel)

      # Note: FCM push notifications are now sent via model callback (send_push_notifications)

      render json: {
        success: true,
        message: serialize_message(message)
      }
    else
      render json: { success: false, error: message.errors.full_messages.join(', ') }, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotFound
    render json: { success: false, error: 'Channel not found' }, status: :not_found
  rescue ActionController::ParameterMissing => e
    render json: { success: false, error: "Missing required parameter: #{e.param}" }, status: :bad_request
  end

  # POST /api/v1/channels/:id/media
  def create_media
    channel = Channel.find(params[:id])
    return unless ensure_channel_access(channel)

    user = current_api_user
    message = channel.messages.build(user: user, content: params[:caption].presence || 'Attachment', message_type: 'api')

    if params[:files].present?
      Array(params[:files]).each { |f| message.files.attach(f) }
    end

    if message.save
      broadcast_message(message, channel)

      # Note: FCM push notifications are now sent via model callback (send_push_notifications)

      render json: {
        success: true,
        message: serialize_message(message)
      }
    else
      render_error(message.errors.full_messages.join(', '))
    end
  rescue ActiveRecord::RecordNotFound
    render_error('Channel not found', :not_found)
  end

  # POST /api/v1/users/:id/messages
  def create_dm
    target = User.find(params[:id])
    user = current_api_user
    if target == user
      render_error('Cannot DM self') and return
    end

    channel = find_or_create_dm(user, target)
    message = channel.messages.build(user: user, content: params.require(:message))

    if message.save
      broadcast_message(message, channel)

      # Note: FCM push notifications are now sent via model callback (send_push_notifications)

      render_success({ id: message.id, channel_id: channel.id }, 'DM sent')
    else
      render_error(message.errors.full_messages.join(', '))
    end
  rescue ActiveRecord::RecordNotFound
    render_error('User not found', :not_found)
  rescue ActionController::ParameterMissing => e
    render_error("Missing required parameter: #{e.param}")
  end

  # GET /api/v1/dm/channels
  def dm_channels
    user = current_api_user

    # Get all DM channels where user is a member
    # Use last_message_at column for efficient sorting instead of subquery
    dm_channels = Channel.dm_channels
                        .joins(:channel_memberships)
                        .where(channel_memberships: { user: user })
                        .includes(channel_memberships: :user)
                        .order(Arel.sql('last_message_at DESC NULLS LAST'))

    render json: {
      channels: dm_channels.map do |c|
        other_user = c.other_user(user)
        last_message = c.messages.order(:created_at).last

        {
          id: c.id,
          name: other_user&.username || "Unknown User", # Show as other person's name
          description: nil, # DMs don't need descriptions
          type: 'dm', # Must match iOS ChannelType.directMessage raw value
          member_count: c.member_count,
          online_member_count: c.members.where(is_online: true).count,
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
          is_member: true, # Always true for DMs
          created_at: c.created_at&.iso8601
        }
      end
    }
  end

  # POST /api/v1/dm/start
  def start_dm_by_username
    username = params.require(:username)
    target = User.find_by(username: username)

    if target.nil?
      render_error('User not found', :not_found)
      return
    end

    user = current_api_user
    if target == user
      render_error('Cannot DM self') and return
    end

    channel = find_or_create_dm(user, target)

    render_success({
      channel: {
        id: channel.id,
        name: channel.name,
        type: channel.channel_type,
        members: channel.channel_memberships.includes(:user).map { |m| m.user.username }
      }
    }, 'DM channel ready')
  rescue ActionController::ParameterMissing => e
    render_error("Missing required parameter: #{e.param}")
  end

  private

  def find_or_create_dm(a, b)
    users = [a, b].sort_by(&:id)
    name = "dm-#{users.first.username}-#{users.last.username}"
    Channel.dm_channels.find_by(name: name) || begin
      ch = Channel.create!(name: name, channel_type: 'dm', created_by: a)
      ch.add_member(a)
      ch.add_member(b)
      ch
    end
  end

  # Scope check helpers

  def require_message_read_scope
    require_scope('user:messages', 'channel:*:read')
  end

  def require_message_write_scope
    # Allow user:messages, bot:post, or channel:*:write scopes
    require_scope('user:messages', 'bot:post', 'channel:*:write')
  end

  def require_non_bot_for_dm
    require_non_bot_token && require_scope('user:messages')
  end

  def require_non_bot_for_delete
    require_non_bot_token && require_scope('user:messages')
  end
end
