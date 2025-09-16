class AddWebhookSecretToBots < ActiveRecord::Migration[8.0]
  def change
    add_column :bots, :webhook_secret, :string
  end
end
