class CreateUserKeys < ActiveRecord::Migration[8.1]
  def change
    create_table :user_keys do |t|
      t.integer :user_id, null: false
      t.string :key_version, default: '1'
      t.text :encrypted_hmac_key, null: false

      t.timestamps
    end

    add_index :user_keys, :user_id, unique: true
    add_foreign_key :user_keys, :users
  end
end
