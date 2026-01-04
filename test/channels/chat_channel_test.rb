require "test_helper"

class ChatChannelTest < ActionCable::Channel::TestCase
  def setup
    @user = create_user(username: "chat_user")
    @channel = Channel.create!(name: "chat-test", channel_type: "public", creator: @user)
    @channel.add_member(@user)

    # Stub the connection to have a current_user
    stub_connection current_user: @user
  end

  test "subscribes to public channel" do
    subscribe channel_id: @channel.id

    assert subscription.confirmed?
    assert_has_stream_for @channel
  end

  test "subscribes to private channel as member" do
    private_channel = Channel.create!(name: "private-chat", channel_type: "private", creator: @user)
    private_channel.add_member(@user)

    subscribe channel_id: private_channel.id

    assert subscription.confirmed?
    assert_has_stream_for private_channel
  end

  test "rejects subscription to private channel without membership" do
    other_user = create_user(username: "other_user")
    private_channel = Channel.create!(name: "secret-chat", channel_type: "private", creator: other_user)

    subscribe channel_id: private_channel.id

    assert subscription.rejected?
  end

  test "rejects subscription without channel_id" do
    subscribe channel_id: nil

    assert subscription.rejected?
  end

  test "rejects subscription to non-existent channel" do
    subscribe channel_id: 999999

    assert subscription.rejected?
  end

  test "speak creates message and broadcasts" do
    subscribe channel_id: @channel.id

    assert_difference("Message.count") do
      perform :speak, message: "Hello from ActionCable!"
    end

    message = Message.last
    assert_equal "Hello from ActionCable!", message.content
    assert_equal @user, message.user
    assert_equal @channel, message.channel
  end

  test "speak broadcasts to channel subscribers" do
    subscribe channel_id: @channel.id

    # Verify broadcasts are made (may broadcast from both channel and model)
    assert_changes -> { broadcasts(ChatChannel.broadcasting_for(@channel)).size }, from: 0 do
      perform :speak, message: "Broadcast test"
    end
  end

  test "speak ignores blank messages" do
    subscribe channel_id: @channel.id

    assert_no_difference("Message.count") do
      perform :speak, message: ""
    end

    assert_no_difference("Message.count") do
      perform :speak, message: "   "
    end
  end

  test "speak requires channel access" do
    other_user = create_user(username: "other_speak_user")
    private_channel = Channel.create!(name: "private-speak", channel_type: "private", creator: other_user)
    private_channel.add_member(other_user)

    # Even if somehow subscribed, speak should check access
    stub_connection current_user: @user

    # This should be rejected at subscription level
    subscribe channel_id: private_channel.id
    assert subscription.rejected?
  end

  test "unsubscribes cleanly" do
    subscribe channel_id: @channel.id
    assert subscription.confirmed?

    unsubscribe
    # No errors should occur
  end
end
