class AddPasswordResetSelectorToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :password_reset_token_selector, :string
    add_index :users, :password_reset_token_selector, unique: true
  end
end
