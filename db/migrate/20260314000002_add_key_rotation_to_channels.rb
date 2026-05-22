class AddKeyRotationToChannels < ActiveRecord::Migration[8.1]
  def change
    add_column :channels, :key_epoch, :integer, default: 0, null: false
    add_column :channels, :key_rotation_required, :boolean, default: false, null: false
  end
end
