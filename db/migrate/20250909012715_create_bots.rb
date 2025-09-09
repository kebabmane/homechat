class CreateBots < ActiveRecord::Migration[8.0]
  def change
    create_table :bots do |t|
      t.string :name
      t.text :description
      t.boolean :active
      t.string :bot_type
      t.string :webhook_id

      t.timestamps
    end
  end
end
