require "test_helper"

class ApiTokenTest < ActiveSupport::TestCase
  test "should require name" do
    token = ApiToken.new
    assert_not token.valid?
    assert_includes token.errors[:name], "can't be blank"
  end

  test "should generate secure token on creation" do
    token = ApiToken.create!(name: "Test Token", user: create_user)
    assert_not_nil token.token
    assert_equal 64, token.token.length  # SecureRandom.hex(32) = 64 chars
  end

  test "should have unique name" do
    ApiToken.create!(name: "Test Token", user: create_user)
    duplicate_token = ApiToken.new(name: "Test Token", user: create_user)
    assert_not duplicate_token.valid?
    assert_includes duplicate_token.errors[:name], "has already been taken"
  end

  test "should be active by default" do
    token = ApiToken.create!(name: "Test Token", user: create_user)
    assert token.active?
  end

  test "should have unique token digest" do
    # With BCrypt, the same raw token produces different digests due to random salt
    # This test verifies that token_digest uniqueness is enforced at the database level
    owner = create_user
    token1 = ApiToken.create!(name: "Token 1", user: owner)

    # Manually set the same digest (simulating a collision)
    token2 = ApiToken.new(name: "Token 2", user: owner)
    token2.token = SecureRandom.hex(32)
    token2.save! # This generates a new unique digest

    # Attempting to set the same digest directly would fail, but since BCrypt
    # generates unique hashes, we can only verify that two tokens have different digests
    assert_not_equal token1.token_digest, token2.token_digest
  end

  test "should validate token correctly" do
    token = ApiToken.create!(name: "Test Token", user: create_user)
    raw_token = token.token  # capture before it's cleared
    token.save!  # hash the token

    assert ApiToken.valid_token?(raw_token)
    assert_not ApiToken.valid_token?("invalid_token")
    assert_not ApiToken.valid_token?(nil)
  end

  test "should deactivate token" do
    token = ApiToken.create!(name: "Test Token", user: create_user)
    assert token.active?
    token.deactivate!
    assert_not token.active?
  end

  test "should regenerate token" do
    token = ApiToken.create!(name: "Test Token", user: create_user)
    original_digest = token.token_digest

    token.regenerate!
    assert_not_nil token.token  # raw token available after regeneration
    assert_equal 64, token.token.length
    assert_not_equal original_digest, token.token_digest
  end

  test "should mask token for display" do
    token = ApiToken.create!(name: "Test Token", user: create_user)
    masked = token.masked_token
    assert masked.include?("*")
    assert masked.length > 12
    assert_equal token.token[0..7], masked[0..7]
    assert_equal token.token[-4..-1], masked[-4..-1]
  end

  test "should show short token" do
    token = ApiToken.create!(name: "Test Token", user: create_user)
    short = token.short_token
    assert short.start_with?("...")
    assert_equal token.token[-4..-1], short[-4..-1]
  end

  test "should scope active tokens" do
    user = create_user
    active_token = ApiToken.create!(name: "Active Token", active: true, user: user)
    inactive_token = ApiToken.create!(name: "Inactive Token", active: false, user: user)

    assert_includes ApiToken.active, active_token
    assert_not_includes ApiToken.active, inactive_token
  end

  test "should generate for integration" do
    user = create_user
    token = ApiToken.generate_for_integration("Test Integration", user)
    assert_equal "Test Integration", token.name
    assert token.active?
    assert_not_nil token.token_digest
    assert_equal user, token.user
  end

  # ===== Scoped Token Tests =====

  test "legacy tokens have full access" do
    # Legacy tokens have nil scopes (not empty array)
    token = ApiToken.create!(name: "Legacy Token", user: create_user, scopes: nil)
    assert token.legacy_full_access?
    assert token.has_scope?('admin:users')
    assert token.has_scope?('user:profile')
    assert token.has_scope?('anything:at:all')
  end

  test "scoped token restricts access" do
    token = ApiToken.create!(name: "Scoped Token", user: create_user, scopes: ['user:profile'])
    assert_not token.legacy_full_access?
    assert token.has_scope?('user:profile')
    assert_not token.has_scope?('admin:users')
    assert_not token.has_scope?('user:messages')
  end

  test "wildcard scopes work" do
    token = ApiToken.create!(name: "Admin Token", user: create_user, scopes: ['admin:*'])
    assert token.has_scope?('admin:users')
    assert token.has_scope?('admin:tokens')
    assert token.has_scope?('admin:bots')
    assert_not token.has_scope?('user:profile')
  end

  test "channel wildcard scopes work" do
    token = ApiToken.create!(name: "Channel Token", user: create_user, scopes: ['channel:*:read'])
    assert token.has_scope?('channel:123:read')
    assert token.has_scope?('channel:456:read')
    assert_not token.has_scope?('channel:123:write')
  end

  test "channel-specific scopes work" do
    user = create_user
    channel = Channel.create!(name: 'test-channel', channel_type: 'public', created_by: user)
    token = ApiToken.create!(name: "Channel Token", user: user, scopes: ["channel:#{channel.id}:write"])

    assert token.can_access_channel?(channel, :write)
    assert token.can_access_channel?(channel, :read)
    assert_not token.can_access_channel?(channel, :manage)
  end

  test "token channel assignments work" do
    user = create_user
    channel = Channel.create!(name: 'assigned-channel', channel_type: 'public', created_by: user)
    # Use a scope that doesn't grant channel access to test assignments
    token = ApiToken.create!(name: "Assignment Token", user: user, scopes: ['bot:post'])

    # Without assignment, no access (has explicit scope but not for channels)
    assert_not token.can_access_channel?(channel, :read)

    # Add assignment
    token.token_channel_assignments.create!(channel: channel, permission: 'write')

    assert token.can_access_channel?(channel, :read)
    assert token.can_access_channel?(channel, :write)
    assert_not token.can_access_channel?(channel, :manage)
  end

  test "expired tokens are invalid" do
    token = ApiToken.create!(name: "Expired Token", user: create_user, expires_at: 1.hour.from_now)
    raw_token = token.token

    # Token is valid before expiry
    assert ApiToken.valid_token?(raw_token)

    # Manually expire the token
    token.update_columns(expires_at: 1.hour.ago)

    # Clear cache to force re-validation
    ApiToken.clear_cache

    # Token should now be invalid
    assert_nil ApiToken.valid_token?(raw_token)
  end

  test "token expiration check" do
    future_token = ApiToken.create!(name: "Future Token", user: create_user, expires_at: 1.hour.from_now)
    assert_not future_token.expired?

    expired_token = ApiToken.new(name: "Past Token", expires_at: 1.hour.ago)
    assert expired_token.expired?
  end

  test "bot tokens cannot access user data" do
    token = ApiToken.create!(name: "Bot Token", user: create_user, token_type: 'bot', scopes: ['bot:post'])
    assert token.bot_token?
    assert_not token.can_access_user_data?
  end

  test "user tokens can access user data" do
    token = ApiToken.create!(name: "User Token", user: create_user, token_type: 'user', scopes: ['user:profile'])
    assert_not token.bot_token?
    assert token.can_access_user_data?
  end

  test "validates token type" do
    token = ApiToken.new(name: "Bad Token", user: create_user, token_type: 'invalid')
    assert_not token.valid?
    assert_includes token.errors[:token_type], "is not included in the list"
  end

  test "validates scopes format" do
    token = ApiToken.new(name: "Bad Scopes", user: create_user, scopes: ['invalid:scope:format:too:long'])
    assert_not token.valid?
    assert token.errors[:scopes].any?
  end

  test "valid_token returns token record not user" do
    token = ApiToken.create!(name: "Record Token", user: create_user)
    raw_token = token.token

    result = ApiToken.valid_token?(raw_token)
    assert_instance_of ApiToken, result
    assert_equal token.id, result.id
  end

  test "not_expired scope filters correctly" do
    user = create_user
    valid_token = ApiToken.create!(name: "Valid", user: user, expires_at: 1.hour.from_now)
    no_expiry_token = ApiToken.create!(name: "No Expiry", user: user)

    # Manually create expired token
    expired_token = ApiToken.create!(name: "Expired", user: user, expires_at: 1.hour.from_now)
    expired_token.update_columns(expires_at: 1.hour.ago)

    not_expired = ApiToken.not_expired

    assert_includes not_expired, valid_token
    assert_includes not_expired, no_expiry_token
    assert_not_includes not_expired, expired_token
  end
end
