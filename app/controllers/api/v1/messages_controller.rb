class Api::V1::MessagesController < Api::V1::BaseController
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
        # Broadcast the message to the channel
        broadcast_message(message, channel)
        
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
      if channel_id
        channel = Channel.find(channel_id)
        messages = channel.messages.includes(:user).order(created_at: :desc).limit(limit)
      else
        messages = Message.includes(:user, :channel).order(created_at: :desc).limit(limit)
      end
      
      render json: {
        messages: messages.map do |message|
          {
            id: message.id,
            content: message.content,
            user: message.user.username,
            channel: message.channel.name,
            created_at: message.created_at.iso8601,
            message_type: message.message_type || 'chat'
          }
        end
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
    if room_id.present?
      # Try to find existing channel by name or create new one
      Channel.find_by(name: room_id) || Channel.create!(
        name: room_id,
        description: "Auto-created channel for Home Assistant integration",
        channel_type: 'public',
        created_by: current_api_user
      )
    else
      # Use default general channel or create it
      Channel.find_by(name: 'general') || Channel.find_by(name: 'home-assistant') || 
      Channel.create!(
        name: 'home-assistant',
        description: 'Home Assistant notifications and messages',
        channel_type: 'public',
        created_by: current_api_user
      )
    end
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
            username: message.user.username
          },
          created_at: message.created_at.iso8601,
          message_type: message.message_type
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
    user = current_api_user
    message = channel.messages.build(user: user, content: params.require(:message))

    if message.save
      broadcast_message(message, channel)
      render_success({ id: message.id, channel_id: channel.id }, 'Message sent')
    else
      render_error(message.errors.full_messages.join(', '))
    end
  rescue ActiveRecord::RecordNotFound
    render_error('Channel not found', :not_found)
  rescue ActionController::ParameterMissing => e
    render_error("Missing required parameter: #{e.param}")
  end

  # POST /api/v1/channels/:id/media
  def create_media
    channel = Channel.find(params[:id])
    user = current_api_user
    message = channel.messages.build(user: user, content: params[:caption].presence || 'Attachment')

    if params[:files].present?
      Array(params[:files]).each { |f| message.files.attach(f) }
    end

    if message.save
      broadcast_message(message, channel)
      render_success({ id: message.id, channel_id: channel.id, files: message.files.map(&:filename) }, 'Media uploaded')
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
      render_success({ id: message.id, channel_id: channel.id }, 'DM sent')
    else
      render_error(message.errors.full_messages.join(', '))
    end
  rescue ActiveRecord::RecordNotFound
    render_error('User not found', :not_found)
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
end
