class AddTokenHashIndexToApiTokens < ActiveRecord::Migration[8.0]
  def change
    # Add an index on the first 8 characters of the token_hash for faster lookups
    # This is a prefix index that helps with the initial token matching
    # The full BCrypt comparison is still done after the prefix match
    add_column :api_tokens, :token_prefix, :string, limit: 8

    add_index :api_tokens, :token_prefix
    add_index :api_tokens, [:active, :token_prefix], name: "index_api_tokens_on_active_and_prefix"
  end
end
