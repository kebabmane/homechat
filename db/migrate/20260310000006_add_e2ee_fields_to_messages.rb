class AddE2eeFieldsToMessages < ActiveRecord::Migration[8.1]
  def change
    add_column :messages, :encrypted_content, :text
    add_column :messages, :content_encoding, :string, null: false, default: 'plaintext'
  end
end
