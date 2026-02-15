class CreateTokenChannelAssignments < ActiveRecord::Migration[8.0]
  def change
    create_table :token_channel_assignments do |t|
      t.references :api_token, null: false, foreign_key: true
      t.references :channel, null: false, foreign_key: true
      t.string :permission, null: false, default: 'read'

      t.timestamps
    end

    add_index :token_channel_assignments, [:api_token_id, :channel_id], unique: true, name: 'idx_token_channel_unique'
  end
end
