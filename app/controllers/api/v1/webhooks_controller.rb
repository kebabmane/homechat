class Api::V1::WebhooksController < Api::V1::BaseController
  skip_before_action :authenticate_api_request, only: [:receive]
  before_action :authenticate_webhook, only: [:receive]
  
  def receive
    webhook_data = webhook_params
    webhook_id = params[:webhook_id]
    
    Rails.logger.info "Received webhook #{webhook_id}: #{webhook_data}"
    
    # Find the bot associated with this webhook
    bot = Bot.find_by(webhook_id: webhook_id, active: true)
    
    unless bot
      render_error('Bot not found or inactive', :not_found)
      return
    end
    
    begin
      case webhook_data[:action]
      when 'send_message'
        handle_send_message(bot, webhook_data)
      when 'status_update'
        handle_status_update(bot, webhook_data)
      when 'command'
        handle_command(bot, webhook_data)
      else
        # Default: treat as a message to send to HomeChat
        handle_incoming_message(bot, webhook_data)
      end
      
      render json: { status: 'ok', message: 'Webhook processed successfully' }
      
    rescue StandardError => e
      Rails.logger.error "Webhook processing error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      render_error('Failed to process webhook', :internal_server_error)
    end
  end
  
  private
  
  def authenticate_webhook
    # For webhook security, you might want to verify a signature
    # For now, we'll use the webhook_id as basic authentication
    webhook_id = params[:webhook_id]
    
    unless webhook_id.present? && Bot.exists?(webhook_id: webhook_id)
      render_error('Invalid webhook', :unauthorized)
    end
  end
  
  def webhook_params
    params.permit(:action, :message, :room_id, :user_id, :title, :priority, :data, :command, :args => [])
  end
  
  def handle_send_message(bot, data)
    message_content = data[:message]
    room_id = data[:room_id] || 'home-assistant'
    title = data[:title]
    
    return if message_content.blank?
    
    # Find or create channel
    channel = find_or_create_channel(room_id)
    
    # Create message from bot
    message = channel.messages.build(
      user: bot_user(bot),
      content: format_bot_message(message_content, title, bot.name),
      message_type: 'bot'
    )
    
    if message.save
      broadcast_message(message, channel)
      Rails.logger.info "Bot #{bot.name} sent message to #{channel.name}"
    else
      raise "Failed to create message: #{message.errors.full_messages.join(', ')}"
    end
  end
  
  def handle_status_update(bot, data)
    status = data[:status] || data[:message]
    
    # Log the status update
    Rails.logger.info "Bot #{bot.name} status: #{status}"
    
    # Optionally send status to a dedicated channel
    if status.present?
      channel = find_or_create_channel('bot-status')
      message = channel.messages.build(
        user: bot_user(bot),
        content: "🤖 **Bot Status Update**: #{status}",
        message_type: 'status'
      )
      
      message.save && broadcast_message(message, channel)
    end
  end
  
  def handle_command(bot, data)
    command = data[:command]
    args = data[:args] || []
    
    Rails.logger.info "Bot #{bot.name} command: #{command} #{args.join(' ')}"
    
    case command
    when 'ping'
      respond_to_bot(bot, 'pong', data[:room_id])
    when 'status'
      respond_to_bot(bot, "Bot #{bot.name} is active", data[:room_id])
    when 'echo'
      message = args.join(' ')
      respond_to_bot(bot, message, data[:room_id]) if message.present?
    else
      respond_to_bot(bot, "Unknown command: #{command}", data[:room_id])
    end
  end
  
  def handle_incoming_message(bot, data)
    # Default handler: treat webhook data as a message to post
    message_content = data[:message] || data.to_s
    handle_send_message(bot, { message: message_content, room_id: data[:room_id] })
  end
  
  def respond_to_bot(bot, message, room_id = nil)
    channel = find_or_create_channel(room_id || 'home-assistant')
    
    response_message = channel.messages.build(
      user: bot_user(bot),
      content: message,
      message_type: 'bot_response'
    )
    
    response_message.save && broadcast_message(response_message, channel)
  end
  
  def bot_user(bot)
    # Create or find a user for this bot
    User.find_by(username: bot.name.parameterize) || 
    User.create!(
      username: bot.name.parameterize,
      email: "#{bot.name.parameterize}@bots.homechat.local",
      password: SecureRandom.hex(32),
      admin: false
    )
  rescue ActiveRecord::RecordInvalid
    # If username is taken, use the system user
    User.find_by(username: 'system') || current_api_user
  end
  
  def find_or_create_channel(room_id)
    room_id = 'home-assistant' if room_id.blank?
    
    Channel.find_by(name: room_id) || Channel.create!(
      name: room_id,
      description: "Auto-created channel for #{room_id}",
      private: false
    )
  end
  
  def format_bot_message(content, title, bot_name)
    formatted = content.to_s
    
    if title.present?
      formatted = "**#{title}**\n#{formatted}"
    end
    
    formatted
  end
  
  def broadcast_message(message, channel)
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
          message_type: message.message_type || 'bot'
        }
      }
    )
  rescue => e
    Rails.logger.error "Failed to broadcast bot message: #{e.message}"
  end
end