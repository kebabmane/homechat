require "test_helper"

class ChannelManagementTest < ActionDispatch::IntegrationTest
  test "user can join and leave a public channel" do
    user = create_user(username: "joiner")
    owner = create_user(username: "owner4")
    channel = Channel.create!(name: "public-join", created_by: owner, channel_type: "public")

    sign_in_as(user)
    assert_equal 0, channel.member_count

    post join_channel_path(channel)
    assert_response :redirect
    assert channel.reload.members.include?(user)

    delete leave_channel_path(channel)
    assert_response :redirect
    refute channel.reload.members.include?(user)
  end
end

