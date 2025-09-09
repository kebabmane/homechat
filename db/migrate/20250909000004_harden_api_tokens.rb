class HardenApiTokens < ActiveRecord::Migration[8.0]
  def change
    change_table :api_tokens do |t|
      t.change :active, :boolean, default: true, null: false
    end
    add_index :api_tokens, :token, unique: true unless index_exists?(:api_tokens, :token)
    add_index :api_tokens, :name, unique: true unless index_exists?(:api_tokens, :name)
  end
end

