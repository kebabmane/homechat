class BackfillApiTokenUsers < ActiveRecord::Migration[7.1]
  def change
    reversible do |dir|
      dir.up do
        execute <<~SQL
          UPDATE api_tokens
          SET user_id = (
            SELECT id FROM users WHERE username = 'system' LIMIT 1
          )
          WHERE user_id IS NULL
        SQL
      end
    end
  end
end
