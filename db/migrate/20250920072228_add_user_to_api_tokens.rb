class AddUserToApiTokens < ActiveRecord::Migration[8.0]
  def up
    # Add user_id column as nullable initially
    add_reference :api_tokens, :user, null: true, foreign_key: true

    # Find or create system user for existing tokens using raw SQL to avoid model callbacks
    system_user_id = execute("SELECT id FROM users WHERE username = 'system' LIMIT 1").first&.fetch('id', nil)

    if system_user_id.nil?
      password_digest = BCrypt::Password.create(SecureRandom.hex(16))
      execute <<~SQL
        INSERT INTO users (username, password_digest, role, created_at, updated_at)
        VALUES ('system', '#{password_digest}', 'user', datetime('now'), datetime('now'))
      SQL
      system_user_id = execute("SELECT id FROM users WHERE username = 'system' LIMIT 1").first['id']
    end

    # Update all existing tokens to belong to system user
    execute("UPDATE api_tokens SET user_id = #{system_user_id} WHERE user_id IS NULL")

    # Now make the column non-nullable
    change_column_null :api_tokens, :user_id, false
  end

  def down
    remove_reference :api_tokens, :user, foreign_key: true
  end
end
