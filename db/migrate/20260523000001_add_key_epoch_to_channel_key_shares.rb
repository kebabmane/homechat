class AddKeyEpochToChannelKeyShares < ActiveRecord::Migration[8.1]
  def change
    add_column :channel_key_shares, :key_epoch, :integer, null: false, default: 0
    add_index :channel_key_shares, [ :channel_id, :key_epoch ], if_not_exists: true
  end
end
