require "test_helper"

class ChannelMembershipsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @member = create_user(username: "member_#{SecureRandom.hex(3)}")
    @outsider = create_user(username: "outsider_#{SecureRandom.hex(3)}")
    @channel = Channel.create!(name: "members-#{SecureRandom.hex(3)}", channel_type: "private", creator: @member)
    @channel.add_member(@member)
  end

  test "requires login" do
    get channel_channel_memberships_path(@channel)

    assert_redirected_to signin_path
  end

  test "member can render membership list" do
    sign_in_as(@member)

    get channel_channel_memberships_path(@channel)

    assert_response :ok
    assert_includes response.body, @member.username
  end

  test "non-member cannot render membership list" do
    sign_in_as(@outsider)

    get channel_channel_memberships_path(@channel)

    assert_response :forbidden
  end
end
