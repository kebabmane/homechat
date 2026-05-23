class BackfillBlankApiTokenScopes < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL.squish
      UPDATE api_tokens
      SET scopes = json_array('admin:*', 'user:profile', 'user:channels', 'user:messages')
      WHERE (scopes IS NULL OR scopes = json_array())
        AND (
          token_type = 'admin'
          OR user_id IN (SELECT id FROM users WHERE role = 'admin')
        )
    SQL

    execute <<~SQL.squish
      UPDATE api_tokens
      SET scopes = json_array('bot:post')
      WHERE (scopes IS NULL OR scopes = json_array())
        AND token_type = 'bot'
    SQL

    execute <<~SQL.squish
      UPDATE api_tokens
      SET scopes = json_array('user:profile', 'user:channels', 'user:messages')
      WHERE scopes IS NULL OR scopes = json_array()
    SQL
  end

  def down
    # Intentionally irreversible. Blank scopes previously meant full access.
  end
end
