require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "should require username" do
    user = User.new(password: "secret", password_confirmation: "secret")
    assert_not user.valid?
    assert_includes user.errors[:username], "can't be blank"
  end

  test "should require unique username" do
    create_user(username: "testuser")
    duplicate_user = User.new(username: "testuser", password: "secret", password_confirmation: "secret")
    assert_not duplicate_user.valid?
    assert_includes duplicate_user.errors[:username], "has already been taken"
  end

  test "should require password" do
    user = User.new(username: "testuser")
    assert_not user.valid?
    assert_includes user.errors[:password], "can't be blank"
  end

  test "should default to user role" do
    user = create_user
    assert_equal "user", user.role
    assert_not user.admin?
  end

  test "can be admin" do
    user = create_user(role: "admin")
    assert_equal "admin", user.role
    assert user.admin?
  end

  test "should validate password confirmation" do
    user = User.new(username: "testuser", password: "secret", password_confirmation: "different")
    assert_not user.valid?
    assert_includes user.errors[:password_confirmation], "doesn't match Password"
  end

  test "should authenticate with correct password" do
    user = create_user(password: "secret")
    assert user.authenticate("secret")
    assert_not user.authenticate("wrong")
  end

  test "should have many channel memberships" do
    user = create_user
    initial_count = user.channel_memberships.count # User auto-joins 'home' channel

    channel = Channel.create!(name: "test", channel_type: "public", creator: user)
    ChannelMembership.create!(user: user, channel: channel)

    assert_includes user.channels, channel
    assert_equal initial_count + 1, user.channel_memberships.count
  end

  test "should have many messages" do
    user = create_user
    channel = Channel.create!(name: "test", channel_type: "public", creator: user)
    message = Message.create!(content: "Hello", user: user, channel: channel)

    assert_includes user.messages, message
    assert_equal 1, user.messages.count
  end

  test "should touch updated_at when marked active" do
    user = create_user
    original_time = user.updated_at

    travel 1.minute do
      user.touch
      assert user.updated_at > original_time
    end
  end
end