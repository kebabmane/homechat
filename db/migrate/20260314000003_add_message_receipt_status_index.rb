class AddMessageReceiptStatusIndex < ActiveRecord::Migration[8.1]
  def change
    add_index :message_receipts, [:message_id, :status], name: "index_message_receipts_on_message_id_and_status"
  end
end
