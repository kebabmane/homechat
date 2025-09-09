class AddMessageTypeToMessages < ActiveRecord::Migration[8.0]
  def change
    add_column :messages, :message_type, :string
  end
end
