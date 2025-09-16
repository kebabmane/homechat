class PopulateWebhookSecretsForExistingBots < ActiveRecord::Migration[8.0]
  def up
    # Generate webhook secrets for existing webhook bots that don't have them
    Bot.where(bot_type: 'webhook', webhook_secret: nil).find_each do |bot|
      bot.update_column(:webhook_secret, SecureRandom.hex(32))
    end
  end

  def down
    # Optionally clear webhook secrets if rolling back
    # Bot.where(bot_type: 'webhook').update_all(webhook_secret: nil)
  end
end
