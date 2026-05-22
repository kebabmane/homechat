class AssignDefaultScopesToApiTokens < ActiveRecord::Migration[8.1]
  def up
    # Assign default user scopes to user tokens with empty/nil scopes
    ApiToken.where(token_type: 'user').where("scopes = '[]' OR scopes IS NULL").update_all(
      scopes: ['user:profile', 'user:channels', 'user:messages'].to_json
    )
    # Assign admin scopes to admin tokens with empty/nil scopes
    ApiToken.where(token_type: 'admin').where("scopes = '[]' OR scopes IS NULL").update_all(
      scopes: ['admin:*'].to_json
    )
    # Assign bot scopes to bot tokens with empty/nil scopes
    ApiToken.where(token_type: 'bot').where("scopes = '[]' OR scopes IS NULL").update_all(
      scopes: ['bot:post'].to_json
    )
    # Nil token_type defaults to user behaviour
    ApiToken.where(token_type: nil).where("scopes = '[]' OR scopes IS NULL").update_all(
      scopes: ['user:profile', 'user:channels', 'user:messages'].to_json
    )

    Rails.logger.info "AssignDefaultScopesToApiTokens: migrated #{ApiToken.count} tokens"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
