class AddLastReadAtToChannelMemberships < ActiveRecord::Migration[8.0]
  def change
    add_column :channel_memberships, :last_read_at, :datetime
    add_index :channel_memberships, [:user_id, :last_read_at], name: 'index_channel_memberships_on_user_id_and_last_read_at'
  end
end
