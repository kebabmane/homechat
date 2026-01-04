class AddAiFieldsToBots < ActiveRecord::Migration[7.1]
  def change
    add_reference :bots, :identity_user, foreign_key: { to_table: :users }, index: true
    add_column :bots, :instructions, :text
    add_column :bots, :model, :string
  end
end
