class CreateApiTokens < ActiveRecord::Migration[8.0]
  def change
    create_table :api_tokens do |t|
      t.string :name
      t.string :token
      t.boolean :active
      t.datetime :last_used_at

      t.timestamps
    end
  end
end
