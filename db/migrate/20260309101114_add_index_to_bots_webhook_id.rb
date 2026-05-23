class AddIndexToBotsWebhookId < ActiveRecord::Migration[8.1]
  def change
    add_index :bots, :webhook_id
  end
end
