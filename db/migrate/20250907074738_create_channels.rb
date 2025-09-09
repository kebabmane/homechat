class CreateChannels < ActiveRecord::Migration[8.0]
  def change
    create_table :channels do |t|
      t.string :name, null: false
      t.text :description
      t.string :channel_type, default: 'public', null: false
      t.references :created_by, null: false, foreign_key: { to_table: :users }

      t.timestamps
    end
    
    add_index :channels, :name, unique: true
    add_index :channels, :channel_type
  end
end
