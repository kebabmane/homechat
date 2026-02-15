module Bots
  class Dispatcher
    MENTION_REGEX = Message::MENTION_REGEX

    def initialize(message)
      @message = message
    end

    def call
      return if message.content.blank?
      return if bot_author?
      return unless Bot.active.ai_bots.exists?

      triggers.each do |payload|
        Bots::ResponderJob.perform_later(payload[:bot].id, message.id, payload[:reason])
      end
    end

    private

    attr_reader :message

    def bot_author?
      Bot.where(identity_user_id: message.user_id).exists?
    end

    def triggers
      @triggers ||= begin
        map = {}
        direct_message_bots.each do |bot|
          map[bot.id] = { bot: bot, reason: 'direct_message' }
        end

        mentioned_bots.each do |bot|
          map[bot.id] = { bot: bot, reason: 'mention' }
        end

        map.values
      end
    end

    def mentioned_bots
      mentions = message.content.to_s.scan(MENTION_REGEX).map do |mention|
        mention.is_a?(Array) ? mention.first.to_s.downcase : mention.to_s.downcase
      end.uniq
      return [] if mentions.blank?

      Bot.active.ai_bots.where('LOWER(name) IN (?)', mentions)
    end

    def direct_message_bots
      return [] unless message.channel.dm?

      other_member_ids = message.channel.members.where.not(id: message.user_id).pluck(:id)
      return [] if other_member_ids.blank?

      Bot.active.ai_bots.where(identity_user_id: other_member_ids).to_a
    end
  end
end
