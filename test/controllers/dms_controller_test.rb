require "test_helper"

class DmsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = create_user(username: "dm_user_#{SecureRandom.hex(3)}")
    @target = create_user(username: "dm_target_#{SecureRandom.hex(3)}")
  end

  test "requires login" do
    get new_dm_path

    assert_redirected_to signin_path
  end

  test "creates dm channel with both users and stable name" do
    sign_in_as(@user)

    assert_difference("Channel.dm_channels.count", 1) do
      assert_difference("ChannelMembership.count", 2) do
        post dms_path, params: { username: @target.username }
      end
    end

    channel = Channel.dm_channels.order(:created_at).last
    assert_redirected_to channel_path(channel)
    assert_equal [ @user.id, @target.id ].sort, channel.members.pluck(:id).sort
    assert_equal "dm-#{[ @user, @target ].sort_by(&:id).map(&:username).join('-')}", channel.name
  end

  test "reuses existing dm channel" do
    existing = Channel.create!(
      name: "dm-#{[ @user, @target ].sort_by(&:id).map(&:username).join('-')}",
      channel_type: "dm",
      creator: @user
    )
    existing.add_member(@user)
    existing.add_member(@target)

    sign_in_as(@user)

    assert_no_difference("Channel.count") do
      post dms_path, params: { username: @target.username }
    end

    assert_redirected_to channel_path(existing)
  end

  test "rejects self or missing users" do
    sign_in_as(@user)

    assert_no_difference("Channel.count") do
      post dms_path, params: { username: @user.username }
    end
    assert_redirected_to new_dm_path

    assert_no_difference("Channel.count") do
      get start_dm_path(username: "missing-user")
    end
    assert_redirected_to new_dm_path
  end
end
