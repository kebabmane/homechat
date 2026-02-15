module Bots
  class ResponderJob < ApplicationJob
    queue_as :default

    def perform(bot_id, message_id, reason = 'mention')
      bot = Bot.active.find_by(id: bot_id)
      return unless bot&.ai_bot?

      message = Message.includes(:channel, :user).find_by(id: message_id)
      return unless message
      return if message.user_id == bot.identity_user_id

      identity_user = nil
      channel = nil

      identity_user = ensure_identity_user(bot)
      return unless identity_user
      begin
        identity_user.update_presence!
      rescue => e
        Rails.logger.debug("Failed to update presence for bot #{identity_user.username}: #{e.class} #{e.message}")
      end

      channel = message.channel
      return unless ensure_membership(channel, identity_user)

      broadcast_typing(channel, identity_user, true)

      response = generate_response(bot, identity_user, channel, message, reason)
      return if response.blank?

      channel.messages.create!(
        user: identity_user,
        content: response,
        message_type: 'bot'
      )
    rescue StandardError => e
      Rails.logger.error("Bot responder failed for bot ##{bot_id}: #{e.class} #{e.message}")
      Rails.logger.debug(e.backtrace.join('\n')) if Rails.env.development?

      handle_failure(bot, channel, identity_user, reason) if notify_failure?(reason)
    ensure
      broadcast_typing(channel, identity_user, false)
    end

    private

    def litellm_host
      @litellm_host ||= Rails.cache.fetch('bots.litellm_host', expires_in: 5.minutes) do
        Setting.fetch(:litellm_host, nil)
      end
    end

    def litellm_api_key
      @litellm_api_key ||= Rails.cache.fetch('bots.litellm_api_key', expires_in: 5.minutes) do
        Setting.fetch(:litellm_api_key, nil)
      end
    end

    def ensure_identity_user(bot)
      return bot.identity_user if bot.identity_user.present?

      bot.save!
      bot.identity_user
    end

    def ensure_membership(channel, user)
      return true if channel.channel_memberships.exists?(user_id: user.id)

      if channel.public? || channel.dm?
        channel.add_member(user)
        return true
      end

      Rails.logger.info("Bot #{user.username} not invited to private channel #{channel.name}; skipping")
      false
    end

    def generate_response(bot, identity_user, channel, message, reason)
      host = litellm_host
      if host.blank?
        Rails.logger.warn('LiteLLM host is not configured; skipping bot response')
        return nil
      end

      api_key = litellm_api_key
      if api_key.blank?
        Rails.logger.warn('LiteLLM API key is not configured; skipping bot response')
        return nil
      end

      model = bot.effective_model
      if model.blank?
        Rails.logger.warn("Bot #{bot.name} has no model configured")
        return nil
      end

      conversation = build_conversation(channel, identity_user, bot, reason, message)
      client = LiteLlm::Client.new(host: host, api_key: api_key)
      completion = client.chat(messages: conversation, model: model)
      completion && completion[:content].to_s.strip
    rescue LiteLlm::Error => e
      Rails.logger.error("LiteLLM request failed for bot #{bot.name}: #{e.message}")
      nil
    end

    def build_conversation(channel, identity_user, bot, reason, message)
      system_prompt = bot.instructions.to_s
      if reason == 'mention'
        system_prompt += "\n\nYou were mentioned by @#{message.user.username} in channel '#{channel.name}'. Respond succinctly." if message&.user
      elsif reason == 'direct_message'
        system_prompt += "\n\nYou are in a direct conversation with @#{message.user.username}." if message&.user
      end

      history = channel.messages.includes(:user).order(created_at: :desc).limit(20).to_a.reverse.map do |msg|
        role = msg.user_id == identity_user.id ? 'assistant' : 'user'
        username = msg.user&.username || 'unknown'
        content = role == 'assistant' ? msg.content : "#{username}: #{msg.content}"
        { role: role, content: content }
      end

      [
        { role: 'system', content: system_prompt.strip }
      ] + history
    end

    def handle_failure(bot, channel, identity_user, _reason)
      return unless bot && channel && identity_user

      channel.messages.create!(
        user: identity_user,
        content: "I'm having trouble reaching my AI backend right now. Please try again later.",
        message_type: 'bot_error'
      )
    rescue => e
      Rails.logger.error("Failed to report bot error in channel #{channel&.id}: #{e.class} #{e.message}")
    end

    def notify_failure?(reason)
      reason == 'direct_message'
    end

    def broadcast_typing(channel, identity_user, typing)
      return unless channel && identity_user

      ActionCable.server.broadcast(
        "typing:#{channel.id}",
        {
          username: identity_user.username,
          typing: typing,
          timestamp: Time.current.iso8601
        }
      )
    rescue => e
      Rails.logger.debug("Failed to broadcast typing for bot #{identity_user.username}: #{e.class} #{e.message}")
    end
  end
end
