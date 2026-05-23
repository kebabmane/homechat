# frozen_string_literal: true

require 'digest'

class UpgradeE2eeToDeviceScoped < ActiveRecord::Migration[8.1]
  def up
    add_message_metadata_columns
    upgrade_user_e2ee_keys
    upgrade_channel_key_shares
  end

  def down
    remove_index :channel_key_shares, column: [:channel_id, :recipient_user_id, :recipient_device_id], if_exists: true
    add_index :channel_key_shares, [:channel_id, :recipient_user_id], unique: true, if_not_exists: true

    remove_columns :channel_key_shares, :recipient_device_id, :sender_device_id, :sender_key_fingerprint, :signature, if_exists: true

    remove_index :user_e2ee_keys, column: [:user_id, :device_id], if_exists: true
    add_index :user_e2ee_keys, :user_id, unique: true, if_not_exists: true

    remove_columns :user_e2ee_keys,
                   :device_id,
                   :encryption_public_key,
                   :signing_public_key,
                   :key_fingerprint,
                   :rotation_count,
                   :first_published_at,
                   :last_rotated_at,
                   :last_seen_at,
                   :revoked_at,
                   if_exists: true

    remove_columns :messages, :sender_device_id, :sender_key_fingerprint, :e2ee_version, if_exists: true
  end

  private

  def add_message_metadata_columns
    add_column :messages, :sender_device_id, :string unless column_exists?(:messages, :sender_device_id)
    add_column :messages, :sender_key_fingerprint, :string unless column_exists?(:messages, :sender_key_fingerprint)
    add_column :messages, :e2ee_version, :string unless column_exists?(:messages, :e2ee_version)

    execute <<~SQL
      UPDATE messages
      SET e2ee_version = '1'
      WHERE content_encoding = 'e2ee' AND (e2ee_version IS NULL OR e2ee_version = '')
    SQL

    add_index :messages, :sender_device_id, if_not_exists: true
  end

  def upgrade_user_e2ee_keys
    add_column :user_e2ee_keys, :device_id, :string unless column_exists?(:user_e2ee_keys, :device_id)
    add_column :user_e2ee_keys, :encryption_public_key, :text unless column_exists?(:user_e2ee_keys, :encryption_public_key)
    add_column :user_e2ee_keys, :signing_public_key, :text unless column_exists?(:user_e2ee_keys, :signing_public_key)
    add_column :user_e2ee_keys, :key_fingerprint, :string unless column_exists?(:user_e2ee_keys, :key_fingerprint)
    add_column :user_e2ee_keys, :rotation_count, :integer, default: 0, null: false unless column_exists?(:user_e2ee_keys, :rotation_count)
    add_column :user_e2ee_keys, :first_published_at, :datetime unless column_exists?(:user_e2ee_keys, :first_published_at)
    add_column :user_e2ee_keys, :last_rotated_at, :datetime unless column_exists?(:user_e2ee_keys, :last_rotated_at)
    add_column :user_e2ee_keys, :last_seen_at, :datetime unless column_exists?(:user_e2ee_keys, :last_seen_at)
    add_column :user_e2ee_keys, :revoked_at, :datetime unless column_exists?(:user_e2ee_keys, :revoked_at)

    execute <<~SQL
      UPDATE user_e2ee_keys
      SET device_id = 'legacy-' || user_id
      WHERE device_id IS NULL OR device_id = ''
    SQL

    execute <<~SQL
      UPDATE user_e2ee_keys
      SET encryption_public_key = public_key
      WHERE encryption_public_key IS NULL OR encryption_public_key = ''
    SQL

    execute <<~SQL
      UPDATE user_e2ee_keys
      SET signing_public_key = public_key
      WHERE signing_public_key IS NULL OR signing_public_key = ''
    SQL

    execute <<~SQL
      UPDATE user_e2ee_keys
      SET first_published_at = published_at
      WHERE first_published_at IS NULL
    SQL

    execute <<~SQL
      UPDATE user_e2ee_keys
      SET last_seen_at = updated_at
      WHERE last_seen_at IS NULL
    SQL

    rows = select_all('SELECT id, encryption_public_key, signing_public_key FROM user_e2ee_keys')
    rows.each do |row|
      fingerprint = Digest::SHA256.hexdigest("#{row['encryption_public_key']}|#{row['signing_public_key']}")
      execute <<~SQL
        UPDATE user_e2ee_keys
        SET key_fingerprint = #{quote(fingerprint)}
        WHERE id = #{row['id'].to_i} AND (key_fingerprint IS NULL OR key_fingerprint = '')
      SQL
    end

    change_column_null :user_e2ee_keys, :device_id, false
    change_column_null :user_e2ee_keys, :encryption_public_key, false
    change_column_null :user_e2ee_keys, :signing_public_key, false
    change_column_null :user_e2ee_keys, :key_fingerprint, false

    remove_index :user_e2ee_keys, :user_id, if_exists: true
    add_index :user_e2ee_keys, [:user_id, :device_id], unique: true, if_not_exists: true
    add_index :user_e2ee_keys, [:user_id, :key_fingerprint], if_not_exists: true
  end

  def upgrade_channel_key_shares
    add_column :channel_key_shares, :recipient_device_id, :string unless column_exists?(:channel_key_shares, :recipient_device_id)
    add_column :channel_key_shares, :sender_device_id, :string unless column_exists?(:channel_key_shares, :sender_device_id)
    add_column :channel_key_shares, :sender_key_fingerprint, :string unless column_exists?(:channel_key_shares, :sender_key_fingerprint)
    add_column :channel_key_shares, :signature, :text unless column_exists?(:channel_key_shares, :signature)

    execute <<~SQL
      UPDATE channel_key_shares
      SET recipient_device_id = 'legacy-' || recipient_user_id
      WHERE recipient_device_id IS NULL OR recipient_device_id = ''
    SQL

    execute <<~SQL
      UPDATE channel_key_shares
      SET sender_device_id = 'legacy-' || sender_user_id
      WHERE sender_device_id IS NULL OR sender_device_id = ''
    SQL

    execute <<~SQL
      UPDATE channel_key_shares
      SET sender_key_fingerprint = 'legacy-fingerprint'
      WHERE sender_key_fingerprint IS NULL OR sender_key_fingerprint = ''
    SQL

    execute <<~SQL
      UPDATE channel_key_shares
      SET signature = 'legacy-signature'
      WHERE signature IS NULL OR signature = ''
    SQL

    change_column_null :channel_key_shares, :recipient_device_id, false
    change_column_null :channel_key_shares, :sender_device_id, false
    change_column_null :channel_key_shares, :sender_key_fingerprint, false
    change_column_null :channel_key_shares, :signature, false

    remove_index :channel_key_shares, column: [:channel_id, :recipient_user_id], if_exists: true
    add_index :channel_key_shares, [:channel_id, :recipient_user_id, :recipient_device_id], unique: true,
              name: 'index_channel_key_shares_on_channel_user_device', if_not_exists: true
  end
end
