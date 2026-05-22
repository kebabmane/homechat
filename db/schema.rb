# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_03_14_000003) do
  create_table "action_text_rich_texts", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "record_id", null: false
    t.string "record_type", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.integer "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.integer "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "api_tokens", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at"
    t.datetime "last_used_at"
    t.string "name"
    t.json "scopes", default: []
    t.string "token_digest"
    t.string "token_prefix", limit: 8
    t.string "token_type", default: "user"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["active", "token_prefix"], name: "index_api_tokens_on_active_and_prefix"
    t.index ["expires_at"], name: "index_api_tokens_on_expires_at"
    t.index ["name"], name: "index_api_tokens_on_name", unique: true
    t.index ["token_digest"], name: "index_api_tokens_on_token_digest", unique: true
    t.index ["token_prefix"], name: "index_api_tokens_on_token_prefix"
    t.index ["token_type"], name: "index_api_tokens_on_token_type"
    t.index ["user_id"], name: "index_api_tokens_on_user_id"
  end

  create_table "audit_logs", force: :cascade do |t|
    t.string "action", null: false
    t.json "changes_made"
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.json "metadata"
    t.bigint "resource_id"
    t.string "resource_type", null: false
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id"
    t.index ["action"], name: "index_audit_logs_on_action"
    t.index ["created_at"], name: "index_audit_logs_on_created_at"
    t.index ["resource_type", "resource_id"], name: "index_audit_logs_on_resource_type_and_resource_id"
    t.index ["user_id"], name: "index_audit_logs_on_user_id"
  end

  create_table "bots", force: :cascade do |t|
    t.boolean "active"
    t.string "bot_type"
    t.datetime "created_at", null: false
    t.text "description"
    t.integer "identity_user_id"
    t.text "instructions"
    t.string "model"
    t.string "name"
    t.datetime "updated_at", null: false
    t.string "webhook_id"
    t.string "webhook_secret"
    t.index ["identity_user_id"], name: "index_bots_on_identity_user_id"
    t.index ["webhook_id"], name: "index_bots_on_webhook_id"
  end

  create_table "channel_key_shares", force: :cascade do |t|
    t.integer "channel_id", null: false
    t.datetime "created_at", null: false
    t.text "encrypted_channel_key", null: false
    t.string "key_version", default: "1"
    t.string "recipient_device_id", null: false
    t.integer "recipient_user_id", null: false
    t.string "sender_device_id", null: false
    t.string "sender_key_fingerprint", null: false
    t.integer "sender_user_id", null: false
    t.text "signature", null: false
    t.datetime "updated_at", null: false
    t.index ["channel_id", "recipient_user_id", "recipient_device_id"], name: "index_channel_key_shares_on_channel_user_device", unique: true
  end

  create_table "channel_memberships", force: :cascade do |t|
    t.integer "channel_id", null: false
    t.datetime "created_at", null: false
    t.datetime "joined_at", default: -> { "CURRENT_TIMESTAMP" }
    t.datetime "last_read_at"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["channel_id"], name: "index_channel_memberships_on_channel_id"
    t.index ["user_id", "channel_id"], name: "index_channel_memberships_on_user_id_and_channel_id", unique: true
    t.index ["user_id", "last_read_at"], name: "index_channel_memberships_on_user_id_and_last_read_at"
    t.index ["user_id"], name: "index_channel_memberships_on_user_id"
  end

  create_table "channels", force: :cascade do |t|
    t.string "channel_type", default: "public", null: false
    t.datetime "created_at", null: false
    t.integer "created_by_id", null: false
    t.text "description"
    t.integer "key_epoch", default: 0, null: false
    t.boolean "key_rotation_required", default: false, null: false
    t.datetime "last_message_at"
    t.integer "memberships_count", default: 0, null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["channel_type"], name: "index_channels_on_channel_type"
    t.index ["created_by_id"], name: "index_channels_on_created_by_id"
    t.index ["last_message_at"], name: "index_channels_on_last_message_at"
    t.index ["name"], name: "index_channels_on_name", unique: true
  end

  create_table "message_receipts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "message_id", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["message_id", "status"], name: "index_message_receipts_on_message_id_and_status"
    t.index ["message_id", "user_id"], name: "index_message_receipts_on_message_id_and_user_id", unique: true
    t.index ["message_id"], name: "index_message_receipts_on_message_id"
    t.index ["user_id"], name: "index_message_receipts_on_user_id"
  end

  create_table "messages", force: :cascade do |t|
    t.integer "channel_id", null: false
    t.text "content", null: false
    t.string "content_encoding", default: "plaintext", null: false
    t.string "content_hmac"
    t.datetime "created_at", null: false
    t.string "e2ee_version"
    t.text "encrypted_content"
    t.string "message_type"
    t.string "sender_device_id"
    t.string "sender_key_fingerprint"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["channel_id", "created_at"], name: "index_messages_on_channel_id_and_created_at"
    t.index ["channel_id"], name: "index_messages_on_channel_id"
    t.index ["message_type"], name: "index_messages_on_message_type"
    t.index ["sender_device_id"], name: "index_messages_on_sender_device_id"
    t.index ["user_id", "created_at"], name: "index_messages_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_messages_on_user_id"
  end

  create_table "settings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.text "value"
    t.index ["key"], name: "index_settings_on_key", unique: true
  end

  create_table "token_channel_assignments", force: :cascade do |t|
    t.integer "api_token_id", null: false
    t.integer "channel_id", null: false
    t.datetime "created_at", null: false
    t.string "permission", default: "read", null: false
    t.datetime "updated_at", null: false
    t.index ["api_token_id", "channel_id"], name: "idx_token_channel_unique", unique: true
    t.index ["api_token_id"], name: "index_token_channel_assignments_on_api_token_id"
    t.index ["channel_id"], name: "index_token_channel_assignments_on_channel_id"
  end

  create_table "user_e2ee_keys", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "device_id", null: false
    t.text "encryption_public_key", null: false
    t.datetime "first_published_at"
    t.string "key_fingerprint", null: false
    t.string "key_version", default: "1"
    t.datetime "last_rotated_at"
    t.datetime "last_seen_at"
    t.text "public_key", null: false
    t.datetime "published_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.datetime "revoked_at"
    t.integer "rotation_count", default: 0, null: false
    t.text "signing_public_key", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id", "device_id"], name: "index_user_e2ee_keys_on_user_id_and_device_id", unique: true
    t.index ["user_id", "key_fingerprint"], name: "index_user_e2ee_keys_on_user_id_and_key_fingerprint"
  end

  create_table "user_keys", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "encrypted_hmac_key", null: false
    t.string "key_version", default: "1"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_user_keys_on_user_id", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.boolean "approved", default: true, null: false
    t.datetime "approved_at"
    t.integer "approved_by_id"
    t.datetime "created_at", null: false
    t.integer "failed_attempts", default: 0, null: false
    t.string "fcm_token"
    t.boolean "is_online", default: false
    t.datetime "last_failed_at"
    t.datetime "last_seen_at"
    t.datetime "locked_until"
    t.text "otp_backup_codes"
    t.boolean "otp_required_for_login", default: false, null: false
    t.string "otp_secret"
    t.string "password_digest", null: false
    t.datetime "password_reset_sent_at"
    t.string "password_reset_token_digest"
    t.string "password_reset_token_selector"
    t.string "role", default: "user", null: false
    t.string "status", default: "Available"
    t.string "timezone", default: "UTC"
    t.datetime "updated_at", null: false
    t.string "username", null: false
    t.index ["approved"], name: "index_users_on_approved"
    t.index ["approved_by_id"], name: "index_users_on_approved_by_id"
    t.index ["fcm_token"], name: "index_users_on_fcm_token"
    t.index ["is_online"], name: "index_users_on_is_online"
    t.index ["last_seen_at"], name: "index_users_on_last_seen_at"
    t.index ["locked_until"], name: "index_users_on_locked_until"
    t.index ["password_reset_token_digest"], name: "index_users_on_password_reset_token_digest", unique: true
    t.index ["password_reset_token_selector"], name: "index_users_on_password_reset_token_selector", unique: true
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "api_tokens", "users"
  add_foreign_key "audit_logs", "users"
  add_foreign_key "bots", "users", column: "identity_user_id"
  add_foreign_key "channel_key_shares", "channels"
  add_foreign_key "channel_key_shares", "users", column: "recipient_user_id"
  add_foreign_key "channel_key_shares", "users", column: "sender_user_id"
  add_foreign_key "channel_memberships", "channels"
  add_foreign_key "channel_memberships", "users"
  add_foreign_key "channels", "users", column: "created_by_id"
  add_foreign_key "message_receipts", "messages"
  add_foreign_key "message_receipts", "users"
  add_foreign_key "messages", "channels"
  add_foreign_key "messages", "users"
  add_foreign_key "token_channel_assignments", "api_tokens"
  add_foreign_key "token_channel_assignments", "channels"
  add_foreign_key "user_e2ee_keys", "users"
  add_foreign_key "user_keys", "users"
end
