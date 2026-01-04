class AddAccountLockoutToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :failed_attempts, :integer, default: 0, null: false
    add_column :users, :locked_until, :datetime
    add_column :users, :last_failed_at, :datetime

    add_index :users, :locked_until
  end
end
