class AddApprovalToUsers < ActiveRecord::Migration[8.0]
  def change
    # Default true so existing users are auto-approved
    add_column :users, :approved, :boolean, default: true, null: false
    add_column :users, :approved_at, :datetime
    add_column :users, :approved_by_id, :integer
    add_index :users, :approved
    add_index :users, :approved_by_id
  end
end
