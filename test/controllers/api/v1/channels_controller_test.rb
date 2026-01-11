require "test_helper"

class Api::V1::ChannelsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = create_user
    @token = ApiToken.create!(name: "Test Token", user: @user, scopes: nil)
    @raw_token = @token.token
    @public_channel = Channel.create!(name: "public-test", channel_type: "public", creator: @user)
    @private_channel = Channel.create!(name: "private-test", channel_type: "private", creator: @user)
    @other_user = create_user(username: "other_user")
    @public_channel.add_member(@user)
    @private_channel.add_member(@user)
  end

  # Authentication tests
  test "should require authentication for index" do
    get api_v1_channels_path
    assert_response :unauthorized
  end

  test "should require authentication for join" do
    post join_api_v1_channel_path(@public_channel)
    assert_response :unauthorized
  end

  test "should require authentication for leave" do
    delete leave_api_v1_channel_path(@public_channel)
    assert_response :unauthorized
  end

  test "should require authentication for members" do
    get members_api_v1_channel_path(@public_channel)
    assert_response :unauthorized
  end

  # Index tests
  test "should list accessible channels" do
    get api_v1_channels_path,
        headers: { "Authorization" => "Bearer #{@raw_token}" }

    assert_response :success
    json = JSON.parse(response.body)
    assert json["channels"].is_a?(Array)
    channel_names = json["channels"].map { |c| c["name"] }
    assert_includes channel_names, "public-test"
  end

  test "should exclude DM channels from index" do
    dm_channel = Channel.create!(
      name: "dm_#{@user.id}_#{@other_user.id}",
      channel_type: "dm",
      creator: @user
    )
    dm_channel.add_member(@user)
    dm_channel.add_member(@other_user)

    get api_v1_channels_path,
        headers: { "Authorization" => "Bearer #{@raw_token}" }

    assert_response :success
    json = JSON.parse(response.body)
    channel_types = json["channels"].map { |c| c["type"] }
    refute_includes channel_types, "dm"
  end

  test "should include channel metadata in response" do
    Message.create!(content: "Test message", user: @user, channel: @public_channel)

    get api_v1_channels_path,
        headers: { "Authorization" => "Bearer #{@raw_token}" }

    assert_response :success
    json = JSON.parse(response.body)
    channel = json["channels"].find { |c| c["name"] == "public-test" }

    assert_not_nil channel
    assert channel.key?("id")
    assert channel.key?("name")
    assert channel.key?("description")
    assert channel.key?("type")
    assert channel.key?("member_count")
    assert channel.key?("online_member_count")
    assert channel.key?("last_message")
    assert channel.key?("is_member")
    assert channel.key?("created_at")
  end

  test "should show membership status correctly" do
    new_channel = Channel.create!(name: "new-channel", channel_type: "public", creator: @other_user)

    get api_v1_channels_path,
        headers: { "Authorization" => "Bearer #{@raw_token}" }

    assert_response :success
    json = JSON.parse(response.body)

    member_channel = json["channels"].find { |c| c["name"] == "public-test" }
    non_member_channel = json["channels"].find { |c| c["name"] == "new-channel" }

    assert member_channel["is_member"]
    refute non_member_channel["is_member"]
  end

  # Join tests
  test "should join public channel" do
    new_channel = Channel.create!(name: "joinable", channel_type: "public", creator: @other_user)

    assert_difference("ChannelMembership.count") do
      post join_api_v1_channel_path(new_channel),
           headers: { "Authorization" => "Bearer #{@raw_token}" }
    end

    assert_response :success
    json = JSON.parse(response.body)
    assert json["success"]
  end

  test "should not join channel twice" do
    assert_no_difference("ChannelMembership.count") do
      post join_api_v1_channel_path(@public_channel),
           headers: { "Authorization" => "Bearer #{@raw_token}" }
    end

    assert_response :bad_request
    json = JSON.parse(response.body)
    assert_match /already/i, json["error"]
  end

  test "should not join inaccessible private channel" do
    private_channel = Channel.create!(name: "secret", channel_type: "private", creator: @other_user)

    post join_api_v1_channel_path(private_channel),
         headers: { "Authorization" => "Bearer #{@raw_token}" }

    assert_response :forbidden
  end

  test "should return 404 for non-existent channel join" do
    post join_api_v1_channel_path(id: 999999),
         headers: { "Authorization" => "Bearer #{@raw_token}" }

    assert_response :not_found
  end

  # Leave tests
  test "should leave channel" do
    assert_difference("ChannelMembership.count", -1) do
      delete leave_api_v1_channel_path(@public_channel),
             headers: { "Authorization" => "Bearer #{@raw_token}" }
    end

    assert_response :success
  end

  test "should not leave channel not a member of" do
    new_channel = Channel.create!(name: "not-member", channel_type: "public", creator: @other_user)

    delete leave_api_v1_channel_path(new_channel),
           headers: { "Authorization" => "Bearer #{@raw_token}" }

    assert_response :bad_request
    json = JSON.parse(response.body)
    assert_match /not a member/i, json["error"]
  end

  test "should return 404 for non-existent channel leave" do
    delete leave_api_v1_channel_path(id: 999999),
           headers: { "Authorization" => "Bearer #{@raw_token}" }

    assert_response :not_found
  end

  # Members tests
  test "should list channel members" do
    get members_api_v1_channel_path(@public_channel),
        headers: { "Authorization" => "Bearer #{@raw_token}" }

    assert_response :success
    json = JSON.parse(response.body)
    assert json["members"].is_a?(Array)
    assert json["members"].any? { |m| m["username"] == @user.username }
  end

  test "should include member details in response" do
    get members_api_v1_channel_path(@public_channel),
        headers: { "Authorization" => "Bearer #{@raw_token}" }

    assert_response :success
    json = JSON.parse(response.body)
    member = json["members"].first

    assert member.key?("id")
    assert member.key?("username")
    assert member.key?("is_online")
    assert member.key?("avatar_initials")
    assert member.key?("avatar_color_index")
  end

  test "should not access private channel members without membership" do
    private_channel = Channel.create!(name: "secret-channel", channel_type: "private", creator: @other_user)
    private_channel.add_member(@other_user)

    get members_api_v1_channel_path(private_channel),
        headers: { "Authorization" => "Bearer #{@raw_token}" }

    assert_response :forbidden
  end

  test "should return 404 for non-existent channel members" do
    get members_api_v1_channel_path(id: 999999),
        headers: { "Authorization" => "Bearer #{@raw_token}" }

    assert_response :not_found
  end

  # X-API-Key header support
  test "should accept X-API-Key header for authentication" do
    get api_v1_channels_path,
        headers: { "X-API-Key" => @raw_token }

    assert_response :success
  end

  # Unread count tests
  test "should include unread_count in channel response" do
    get api_v1_channels_path,
        headers: { "Authorization" => "Bearer #{@raw_token}" }

    assert_response :success
    json = JSON.parse(response.body)
    channel = json["channels"].find { |c| c["name"] == "public-test" }

    assert channel.key?("unread_count")
    assert_equal 0, channel["unread_count"]
  end

  test "should return correct unread count for messages after last_read_at" do
    # Create a message from another user
    Message.create!(content: "New message", user: @other_user, channel: @public_channel)

    get api_v1_channels_path,
        headers: { "Authorization" => "Bearer #{@raw_token}" }

    assert_response :success
    json = JSON.parse(response.body)
    channel = json["channels"].find { |c| c["name"] == "public-test" }

    # Should have 1 unread message (from another user)
    assert_equal 1, channel["unread_count"]
  end

  test "should not count own messages as unread" do
    # Create a message from the current user
    Message.create!(content: "My own message", user: @user, channel: @public_channel)

    get api_v1_channels_path,
        headers: { "Authorization" => "Bearer #{@raw_token}" }

    assert_response :success
    json = JSON.parse(response.body)
    channel = json["channels"].find { |c| c["name"] == "public-test" }

    # Own messages should not count as unread
    assert_equal 0, channel["unread_count"]
  end

  # Mark as read tests
  test "should require authentication for mark_as_read" do
    post mark_as_read_api_v1_channel_path(@public_channel)
    assert_response :unauthorized
  end

  test "should mark channel as read" do
    # Create an unread message
    Message.create!(content: "Unread message", user: @other_user, channel: @public_channel)

    # Mark as read
    post mark_as_read_api_v1_channel_path(@public_channel),
         headers: { "Authorization" => "Bearer #{@raw_token}" }

    assert_response :success
    json = JSON.parse(response.body)
    assert json["success"]
    assert_equal 0, json["unread_count"]
  end

  test "should update last_read_at when marking as read" do
    membership = @public_channel.channel_memberships.find_by(user: @user)
    assert_nil membership.last_read_at

    post mark_as_read_api_v1_channel_path(@public_channel),
         headers: { "Authorization" => "Bearer #{@raw_token}" }

    assert_response :success
    membership.reload
    assert_not_nil membership.last_read_at
  end

  test "should return error when marking non-member channel as read" do
    new_channel = Channel.create!(name: "not-member-channel", channel_type: "public", creator: @other_user)

    post mark_as_read_api_v1_channel_path(new_channel),
         headers: { "Authorization" => "Bearer #{@raw_token}" }

    assert_response :forbidden
  end

  test "should return 404 for non-existent channel mark_as_read" do
    post mark_as_read_api_v1_channel_path(id: 999999),
         headers: { "Authorization" => "Bearer #{@raw_token}" }

    assert_response :not_found
  end

  test "should reset unread count after marking as read" do
    # Create messages from another user
    Message.create!(content: "Message 1", user: @other_user, channel: @public_channel)
    Message.create!(content: "Message 2", user: @other_user, channel: @public_channel)

    # Mark as read
    post mark_as_read_api_v1_channel_path(@public_channel),
         headers: { "Authorization" => "Bearer #{@raw_token}" }

    assert_response :success

    # Verify unread count is now 0
    get api_v1_channels_path,
        headers: { "Authorization" => "Bearer #{@raw_token}" }

    json = JSON.parse(response.body)
    channel = json["channels"].find { |c| c["name"] == "public-test" }
    assert_equal 0, channel["unread_count"]
  end
end
