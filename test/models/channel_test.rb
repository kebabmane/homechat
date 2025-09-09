require "test_helper"

class ChannelTest < ActiveSupport::TestCase
  test "valid channel and member management" do
    owner = create_user(username: "owner")
    channel = Channel.create!(name: "general", description: "Gen", channel_type: "public", created_by: owner)

    user = create_user(username: "alice")
    assert_equal 0, channel.member_count
    assert channel.add_member(user)
    assert_equal 1, channel.member_count
    channel.remove_member(user)
    assert_equal 0, channel.member_count
  end

  test "scopes work" do
    owner = create_user(username: "owner2")
    public_ch = Channel.create!(name: "public1", channel_type: "public", created_by: owner)
    private_ch = Channel.create!(name: "private1", channel_type: "private", created_by: owner)
    assert_includes Channel.public_channels, public_ch
    assert_includes Channel.private_channels, private_ch
  end
end

