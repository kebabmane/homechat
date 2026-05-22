require "test_helper"

class ChannelTest < ActiveSupport::TestCase
  test "valid channel and member management" do
    owner = create_user(username: "owner")
    channel = Channel.create!(name: "general", description: "Gen", channel_type: "public", created_by: owner)

    user = create_user(username: "alice")
    assert_equal 0, channel.channel_memberships.count
    membership = channel.add_member(user)
    assert membership.persisted?, "Membership should be persisted"
    assert_equal 1, channel.channel_memberships.count
    channel.remove_member(user)
    assert_equal 0, channel.channel_memberships.count
  end

  test "scopes work" do
    owner = create_user(username: "owner2")
    public_ch = Channel.create!(name: "public1", channel_type: "public", created_by: owner)
    private_ch = Channel.create!(name: "private1", channel_type: "private", created_by: owner)
    assert_includes Channel.public_channels, public_ch
    assert_includes Channel.private_channels, private_ch
  end

  test "unread_count_for returns 0 for nil user" do
    owner = create_user(username: "owner3")
    channel = Channel.create!(name: "test-unread", channel_type: "public", created_by: owner)
    assert_equal 0, channel.unread_count_for(nil)
  end

  test "unread_count_for returns 0 for non-member" do
    owner = create_user(username: "owner4")
    other = create_user(username: "non-member")
    channel = Channel.create!(name: "test-unread2", channel_type: "public", created_by: owner)
    Message.create!(content: "Test", user: owner, channel: channel)

    assert_equal 0, channel.unread_count_for(other)
  end

  test "unread_count_for counts messages after last_read_at" do
    owner = create_user(username: "owner5")
    member = create_user(username: "member")
    channel = Channel.create!(name: "test-unread3", channel_type: "public", created_by: owner)
    channel.add_member(member)

    # Create a message
    Message.create!(content: "New message", user: owner, channel: channel)

    # Should have 1 unread
    assert_equal 1, channel.unread_count_for(member)
  end

  test "unread_count_for excludes own messages" do
    owner = create_user(username: "owner6")
    channel = Channel.create!(name: "test-unread4", channel_type: "public", created_by: owner)
    channel.add_member(owner)

    # Owner creates a message
    Message.create!(content: "My own message", user: owner, channel: channel)

    # Own messages should not count as unread
    assert_equal 0, channel.unread_count_for(owner)
  end

  test "unread_count_for resets after marking as read" do
    owner = create_user(username: "owner7")
    member = create_user(username: "member2")
    channel = Channel.create!(name: "test-unread5", channel_type: "public", created_by: owner)
    channel.add_member(member)

    # Create messages
    Message.create!(content: "Message 1", user: owner, channel: channel)
    Message.create!(content: "Message 2", user: owner, channel: channel)

    assert_equal 2, channel.unread_count_for(member)

    # Mark as read
    membership = channel.channel_memberships.find_by(user: member)
    membership.mark_as_read!

    # Should be 0 now
    assert_equal 0, channel.unread_count_for(member)
  end

  test "unread_count_for counts only messages after last_read_at" do
    owner = create_user(username: "owner8")
    member = create_user(username: "member3")
    channel = Channel.create!(name: "test-unread6", channel_type: "public", created_by: owner)
    channel.add_member(member)

    # Create a message
    Message.create!(content: "Old message", user: owner, channel: channel)

    # Mark as read
    membership = channel.channel_memberships.find_by(user: member)
    membership.mark_as_read!

    # Create a new message
    Message.create!(content: "New message after read", user: owner, channel: channel)

    # Should only count the new message
    assert_equal 1, channel.unread_count_for(member)
  end
end
