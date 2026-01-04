class AddUserToApiTokens < ActiveRecord::Migration[8.0]
  def up
    # Add user_id column as nullable initially
    add_reference :api_tokens, :user, null: true, foreign_key: true

    # Find or create system user for existing tokens
    system_user = User.find_by(username: 'system')
    if system_user.nil?
      password = SecureRandom.hex(16)
      system_user = User.create!(
        username: 'system',
        password: password,
        password_confirmation: password,
        role: 'user'
      )
    end

    # Update existing tokens to belong to appropriate users
    ApiToken.find_each do |token|
      if token.name&.include?('Mobile App -')
        # Extract username from token name like "Mobile App - meow2"
        username = token.name.sub('Mobile App - ', '')
        user = User.find_by(username: username)
        if user
          token.update!(user_id: user.id)
        else
          token.update!(user_id: system_user.id)
        end
      else
        # Non-mobile tokens (like Home Assistant) stay with system user
        token.update!(user_id: system_user.id)
      end
    end

    # Now make the column non-nullable
    change_column_null :api_tokens, :user_id, false
  end

  def down
    remove_reference :api_tokens, :user, foreign_key: true
  end
end
