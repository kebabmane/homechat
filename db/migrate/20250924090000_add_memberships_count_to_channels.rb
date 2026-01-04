class AddMembershipsCountToChannels < ActiveRecord::Migration[7.1]
  def up
    add_column :channels, :memberships_count, :integer, null: false, default: 0

    execute <<~SQL.squish
      UPDATE channels
      SET memberships_count = (
        SELECT COUNT(*)
        FROM channel_memberships
        WHERE channel_memberships.channel_id = channels.id
      )
    SQL
  end

  def down
    remove_column :channels, :memberships_count
  end
end
