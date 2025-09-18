class AddPresenceToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :last_seen_at, :datetime
    add_column :users, :status, :string, default: 'Available'
    add_column :users, :is_online, :boolean, default: false

    add_index :users, :is_online
    add_index :users, :last_seen_at
  end
end
