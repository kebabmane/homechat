require "test_helper"

class ChatChannelTest < ActionCable::Channel::TestCase
  def setup
    @user = create_user(username: "chat_user")
    @channel = Channel.create!(name: "chat-test", channel_type: "public", creator: @user)
    @channel.add_member(@user)

    # Stub the connection to have a current_user and current_api_token_id
    stub_connection current_user: @user, current_api_token_id: nil
  end

  test "subscribes to public channel" do
    subscribe channel_id: @channel.id

    assert subscription.confirmed?
    assert_has_stream "chat_channel_#{@channel.id}"
  end

  test "subscribes to private channel as member" do
    private_channel = Channel.create!(name: "private-chat", channel_type: "private", creator: @user)
    private_channel.add_member(@user)

    subscribe channel_id: private_channel.id

    assert subscription.confirmed?
    assert_has_stream "chat_channel_#{private_channel.id}"
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
    assert_changes -> { broadcasts("chat_channel_#{@channel.id}").size }, from: 0 do
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
    stub_connection current_user: @user, current_api_token_id: nil

    # This should be rejected at subscription level
    subscribe channel_id: private_channel.id
    assert subscription.rejected?
  end

  test "speak rejects plaintext in private channels" do
    private_channel = Channel.create!(name: "private-e2ee-#{SecureRandom.hex(2)}", channel_type: "private", creator: @user)
    private_channel.add_member(@user)

    subscribe channel_id: private_channel.id
    assert subscription.confirmed?

    assert_no_difference("Message.count") do
      perform :speak, message: "private plaintext"
    end
  end

  test "speak accepts e2ee payload in private channels" do
    private_channel = Channel.create!(name: "private-e2ee-ok-#{SecureRandom.hex(2)}", channel_type: "private", creator: @user)
    private_channel.add_member(@user)

    # Register a device key so the sender identity check passes
    encryption_public_key = Base64.strict_encode64(SecureRandom.bytes(32))
    signing_public_key = Base64.strict_encode64(SecureRandom.bytes(32))
    key_fingerprint = E2eePolicy.bundle_fingerprint(encryption_public_key, signing_public_key)
    UserE2eeKey.create!(
      user: @user,
      device_id: "device-chat-test",
      encryption_public_key: encryption_public_key,
      signing_public_key: signing_public_key,
      key_fingerprint: key_fingerprint
    )

    subscribe channel_id: private_channel.id
    assert subscription.confirmed?

    assert_difference("Message.count") do
      perform :speak,
              message: "ignored",
              content_encoding: "e2ee",
              encrypted_content: "{\"v\":\"1\",\"iv\":\"abc\",\"ciphertext\":\"def\"}",
              content_hmac: "hmac",
              device_id: "device-chat-test",
              e2ee_version: "1",
              sender_key_fingerprint: key_fingerprint
    end

    message = Message.last
    assert_equal "e2ee", message.content_encoding
    assert_equal E2eePolicy::PLACEHOLDER_CONTENT, message.content
  end

  test "unsubscribes cleanly" do
    subscribe channel_id: @channel.id
    assert subscription.confirmed?

    unsubscribe
    # No errors should occur
  end
end
