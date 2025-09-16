require "test_helper"

class ApiTokenTest < ActiveSupport::TestCase
  test "should require name" do
    token = ApiToken.new
    assert_not token.valid?
    assert_includes token.errors[:name], "can't be blank"
  end

  test "should generate secure token on creation" do
    token = ApiToken.create!(name: "Test Token")
    assert_not_nil token.token
    assert_equal 64, token.token.length  # SecureRandom.hex(32) = 64 chars
  end

  test "should have unique name" do
    ApiToken.create!(name: "Test Token")
    duplicate_token = ApiToken.new(name: "Test Token")
    assert_not duplicate_token.valid?
    assert_includes duplicate_token.errors[:name], "has already been taken"
  end

  test "should be active by default" do
    token = ApiToken.create!(name: "Test Token")
    assert token.active?
  end

  test "should have unique token" do
    token1 = ApiToken.create!(name: "Token 1")
    token2 = ApiToken.new(name: "Token 2", token: token1.token)
    assert_not token2.valid?
    assert_includes token2.errors[:token], "has already been taken"
  end

  test "should validate token correctly" do
    token = ApiToken.create!(name: "Test Token")
    assert ApiToken.valid_token?(token.token)
    assert_not ApiToken.valid_token?("invalid_token")
    assert_not ApiToken.valid_token?(nil)
  end

  test "should deactivate token" do
    token = ApiToken.create!(name: "Test Token")
    assert token.active?
    token.deactivate!
    assert_not token.active?
  end

  test "should regenerate token" do
    token = ApiToken.create!(name: "Test Token")
    original_token = token.token
    token.regenerate!
    token.reload # Reload to get the updated token from database
    assert_not_equal original_token, token.token
    assert_equal 64, token.token.length
  end

  test "should mask token for display" do
    token = ApiToken.create!(name: "Test Token")
    masked = token.masked_token
    assert masked.include?("*")
    assert masked.length > 12
    assert_equal token.token[0..7], masked[0..7]
    assert_equal token.token[-4..-1], masked[-4..-1]
  end

  test "should show short token" do
    token = ApiToken.create!(name: "Test Token")
    short = token.short_token
    assert short.start_with?("...")
    assert_equal token.token[-4..-1], short[-4..-1]
  end

  test "should scope active tokens" do
    active_token = ApiToken.create!(name: "Active Token", active: true)
    inactive_token = ApiToken.create!(name: "Inactive Token", active: false)

    assert_includes ApiToken.active, active_token
    assert_not_includes ApiToken.active, inactive_token
  end

  test "should generate for integration" do
    token = ApiToken.generate_for_integration("Test Integration")
    assert_equal "Test Integration", token.name
    assert token.active?
    assert_not_nil token.token
  end
end