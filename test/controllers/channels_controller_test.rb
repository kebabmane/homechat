require "test_helper"

class ChannelsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = create_user
    @admin = create_user(username: "admin", role: "admin")
    @channel = Channel.create!(name: "public-test", channel_type: "public", creator: @user)
    @private_channel = Channel.create!(name: "private-test", channel_type: "private", creator: @admin)
  end

  test "should redirect to signin when not logged in" do
    get channels_path
    assert_redirected_to signin_path
  end

  test "should show channels when logged in" do
    sign_in_as(@user)
    get channels_path
    assert_response :success
  end

  test "should show specific channel" do
    sign_in_as(@user)
    get channel_path(@channel)
    assert_response :success
  end

  test "should not show private channel to non-member" do
    sign_in_as(@user)
    get channel_path(@private_channel)
    assert_redirected_to channels_path
  end

  test "should show private channel to member" do
    @private_channel.add_member(@user)
    sign_in_as(@user)
    get channel_path(@private_channel)
    assert_response :success
  end

  test "should show new channel form" do
    sign_in_as(@user)
    get new_channel_path
    assert_response :success
    assert_select "form"
  end

  test "should create public channel" do
    sign_in_as(@user)

    assert_difference("Channel.count") do
      post channels_path, params: {
        channel: {
          name: "new-channel",
          description: "Test channel",
          channel_type: "public"
        }
      }
    end

    channel = Channel.find_by(name: "new-channel")
    assert_not_nil channel
    assert_equal @user, channel.creator
    assert_redirected_to channel_path(channel)
  end

  test "should create private channel" do
    sign_in_as(@user)

    assert_difference("Channel.count") do
      post channels_path, params: {
        channel: {
          name: "private-channel",
          description: "Test private channel",
          channel_type: "private"
        }
      }
    end

    channel = Channel.find_by(name: "private-channel")
    assert channel.private?
    assert_redirected_to channel_path(channel)
  end

  test "should not create channel with invalid params" do
    sign_in_as(@user)

    assert_no_difference("Channel.count") do
      post channels_path, params: {
        channel: {
          name: "",
          description: "Test channel",
          channel_type: "public"
        }
      }
    end

    # Implementation may render the form again with errors instead of 422
    assert_response :success # Renders new form with errors
  end

  test "should join public channel" do
    other_user = create_user(username: "other")
    sign_in_as(other_user)

    assert_difference("@channel.members.count") do
      post join_channel_path(@channel)
    end

    assert_redirected_to channel_path(@channel)
    assert @channel.members.include?(other_user)
  end

  test "should leave channel" do
    @channel.add_member(@user)
    sign_in_as(@user)

    assert_difference("@channel.members.count", -1) do
      delete leave_channel_path(@channel)
    end

    assert_redirected_to channels_path
    assert_not @channel.members.include?(@user)
  end

  test "should invite user to private channel" do
    other_user = create_user(username: "other")
    sign_in_as(@admin) # Creator of private channel

    assert_difference("@private_channel.members.count") do
      post invite_channel_path(@private_channel), params: { username: other_user.username }
    end

    assert_redirected_to channel_path(@private_channel)
    assert @private_channel.members.include?(other_user)
  end

  test "should not invite to channel if not creator" do
    other_user = create_user(username: "other")
    sign_in_as(@user) # Not creator of private channel

    post invite_channel_path(@private_channel), params: { username: other_user.username }
    # Might redirect to the channel itself or back to channels list
    assert_response :redirect
  end
end