class ChangeApiTokensToUseDigest < ActiveRecord::Migration[8.0]
  def change
    add_column :api_tokens, :token_digest, :string
    add_index :api_tokens, :token_digest, unique: true

    # Migrate existing tokens to use digest
    reversible do |dir|
      dir.up do
        # Hash existing tokens
        ApiToken.find_each do |token|
          if token.token.present?
            token.update_column(:token_digest, Digest::SHA256.hexdigest(token.token))
          end
        end
      end
    end

    # Remove old token column after migration
    remove_column :api_tokens, :token, :string
  end
end
