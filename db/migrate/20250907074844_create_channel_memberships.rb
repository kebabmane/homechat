class CreateChannelMemberships < ActiveRecord::Migration[8.0]
  def change
    create_table :channel_memberships do |t|
      t.references :user, null: false, foreign_key: true
      t.references :channel, null: false, foreign_key: true
      t.datetime :joined_at, default: -> { 'CURRENT_TIMESTAMP' }

      t.timestamps
    end
    
    add_index :channel_memberships, [:user_id, :channel_id], unique: true
  end
end
