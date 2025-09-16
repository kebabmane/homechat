require "test_helper"

class ChannelMembershipTest < ActiveSupport::TestCase
  test "should require user" do
    channel = Channel.create!(name: "test", channel_type: "public", creator: create_user)
    membership = ChannelMembership.new(channel: channel)
    assert_not membership.valid?
    assert_includes membership.errors[:user], "must exist"
  end

  test "should require channel" do
    user = create_user
    membership = ChannelMembership.new(user: user)
    assert_not membership.valid?
    assert_includes membership.errors[:channel], "must exist"
  end

  test "should belong to user and channel" do
    user = create_user
    channel = Channel.create!(name: "test", channel_type: "public", creator: user)
    membership = ChannelMembership.create!(user: user, channel: channel)

    assert_equal user, membership.user
    assert_equal channel, membership.channel
  end

  test "should have unique user per channel" do
    user = create_user
    channel = Channel.create!(name: "test", channel_type: "public", creator: user)
    ChannelMembership.create!(user: user, channel: channel)

    duplicate_membership = ChannelMembership.new(user: user, channel: channel)
    assert_not duplicate_membership.valid?
    assert_includes duplicate_membership.errors[:user_id], "has already been taken"
  end

  test "should set joined_at on creation" do
    user = create_user
    channel = Channel.create!(name: "test", channel_type: "public", creator: user)
    membership = ChannelMembership.create!(user: user, channel: channel)

    assert_not_nil membership.joined_at
    assert membership.joined_at.is_a?(Time) || membership.joined_at.is_a?(ActiveSupport::TimeWithZone)
  end

  test "should allow same user in different channels" do
    user = create_user
    channel1 = Channel.create!(name: "channel1", channel_type: "public", creator: user)
    channel2 = Channel.create!(name: "channel2", channel_type: "public", creator: user)

    membership1 = ChannelMembership.create!(user: user, channel: channel1)
    membership2 = ChannelMembership.create!(user: user, channel: channel2)

    assert membership1.valid?
    assert membership2.valid?
  end

  test "should allow different users in same channel" do
    user1 = create_user(username: "user1")
    user2 = create_user(username: "user2")
    channel = Channel.create!(name: "test", channel_type: "public", creator: user1)

    membership1 = ChannelMembership.create!(user: user1, channel: channel)
    membership2 = ChannelMembership.create!(user: user2, channel: channel)

    assert membership1.valid?
    assert membership2.valid?
  end
end