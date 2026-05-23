class CreateUserE2eeKeys < ActiveRecord::Migration[8.1]
  def change
    create_table :user_e2ee_keys do |t|
      t.integer :user_id, null: false
      t.text :public_key, null: false
      t.string :key_version, default: '1'
      t.datetime :published_at, null: false, default: -> { 'CURRENT_TIMESTAMP' }

      t.timestamps
    end

    add_index :user_e2ee_keys, :user_id, unique: true
    add_foreign_key :user_e2ee_keys, :users
  end
end
