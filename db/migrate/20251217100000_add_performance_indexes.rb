class AddPerformanceIndexes < ActiveRecord::Migration[8.0]
  def change
    # Add indexes for messages table to improve query performance
    add_index :messages, [:user_id, :created_at], name: 'index_messages_on_user_id_and_created_at'
    add_index :messages, :message_type, name: 'index_messages_on_message_type'

    # Add last_message_at column to channels for better DM sorting performance
    add_column :channels, :last_message_at, :datetime
    add_index :channels, :last_message_at, name: 'index_channels_on_last_message_at'

    # Backfill last_message_at for existing channels
    reversible do |dir|
      dir.up do
        execute <<-SQL
          UPDATE channels
          SET last_message_at = (
            SELECT MAX(created_at)
            FROM messages
            WHERE messages.channel_id = channels.id
          )
        SQL
      end
    end
  end
end
