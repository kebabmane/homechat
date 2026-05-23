class CreateMessageReceipts < ActiveRecord::Migration[7.1]
  def change
    create_table :message_receipts do |t|
      t.references :message, null: false, foreign_key: true, index: true
      t.references :user,    null: false, foreign_key: true
      t.integer :status, null: false, default: 0  # 0=delivered, 1=read
      t.timestamps
    end
    add_index :message_receipts, [:message_id, :user_id], unique: true
  end
end
