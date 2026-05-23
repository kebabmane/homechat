class CreateChannelKeyShares < ActiveRecord::Migration[8.1]
  def change
    create_table :channel_key_shares do |t|
      t.integer :channel_id, null: false
      t.integer :recipient_user_id, null: false
      t.integer :sender_user_id, null: false
      t.text :encrypted_channel_key, null: false
      t.string :key_version, default: '1'

      t.timestamps
    end

    add_index :channel_key_shares, [:channel_id, :recipient_user_id], unique: true
    add_foreign_key :channel_key_shares, :channels
    add_foreign_key :channel_key_shares, :users, column: :recipient_user_id
    add_foreign_key :channel_key_shares, :users, column: :sender_user_id
  end
end
