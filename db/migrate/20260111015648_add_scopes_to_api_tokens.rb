class AddScopesToApiTokens < ActiveRecord::Migration[8.0]
  def change
    add_column :api_tokens, :scopes, :json, default: []
    add_column :api_tokens, :expires_at, :datetime, null: true
    add_column :api_tokens, :token_type, :string, default: 'user'

    add_index :api_tokens, :expires_at
    add_index :api_tokens, :token_type
  end
end
