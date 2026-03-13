require "test_helper"

class MessageBroadcasterTest < ActiveSupport::TestCase
  def setup
    @user = create_user(username: "broadcaster_user")
    @channel = Channel.create!(
      name: "broadcast-test",
      channel_type: "public",
      creator: @user
    )
    @channel.add_member(@user)
  end

  # ─────────────────────────────────────────────────────────────────────────
  # broadcast_to_action_cable payload structure
  # ─────────────────────────────────────────────────────────────────────────

  test "broadcast_to_action_cable includes content_encoding in payload" do
    message = Message.create!(
      content: "hello",
      content_encoding: "plaintext",
      channel: @channel,
      user: @user,
      skip_chat_broadcast: false
    )

    captured = capture_broadcast(@channel) do
      MessageBroadcaster.new(message).send(:broadcast_to_action_cable)
    end

    assert captured.dig(:message, :content_encoding).present?,
      "Payload should include content_encoding field"
    assert_equal "plaintext", captured.dig(:message, :content_encoding)
  end

  test "broadcast_to_action_cable includes encrypted_content in payload (nil for plaintext)" do
    message = Message.create!(
      content: "plain text message",
      content_encoding: "plaintext",
      channel: @channel,
      user: @user
    )

    captured = capture_broadcast(@channel) do
      MessageBroadcaster.new(message).send(:broadcast_to_action_cable)
    end

    assert captured[:message].key?(:encrypted_content),
      "Payload should include encrypted_content key even when nil"
    assert_nil captured.dig(:message, :encrypted_content),
      "encrypted_content should be nil for a plaintext message"
  end

  test "broadcast_to_action_cable includes encrypted_content for E2EE message" do
    message = Message.create!(
      content: "[Encrypted]",
      content_encoding: "e2ee",
      encrypted_content: "Base64CiphertextHere==",
      content_hmac: "hmac-e2ee==",
      channel: @channel,
      user: @user
    )

    captured = capture_broadcast(@channel) do
      MessageBroadcaster.new(message).send(:broadcast_to_action_cable)
    end

    assert_equal "Base64CiphertextHere==", captured.dig(:message, :encrypted_content),
      "Payload should carry the encrypted_content for E2EE messages"
    assert_equal "e2ee", captured.dig(:message, :content_encoding)
    assert_nil captured.dig(:message, :content),
      "Payload should not include plaintext content for E2EE messages"
  end

  test "broadcast_to_action_cable includes content_hmac in payload" do
    message = Message.create!(
      content: "hmac-signed message",
      content_hmac: "sha256hmacvalue==",
      channel: @channel,
      user: @user
    )

    captured = capture_broadcast(@channel) do
      MessageBroadcaster.new(message).send(:broadcast_to_action_cable)
    end

    assert captured[:message].key?(:content_hmac),
      "Payload should include content_hmac key"
    assert_equal "sha256hmacvalue==", captured.dig(:message, :content_hmac)
  end

  test "broadcast_to_action_cable does not log message content" do
    message = Message.create!(
      content: "do not log me",
      channel: @channel,
      user: @user
    )

    logged_messages = []
    logger_stub = Object.new
    logger_stub.define_singleton_method(:info) { |msg| logged_messages << msg.to_s }
    logger_stub.define_singleton_method(:error) { |_| }
    logger_stub.define_singleton_method(:warn) { |_| }
    logger_stub.define_singleton_method(:debug) { |_| }

    Rails.stub(:logger, logger_stub) do
      ActionCable.server.stub(:broadcast, ->(_stream, _payload) {}) do
        MessageBroadcaster.new(message).send(:broadcast_to_action_cable)
      end
    end

    logged_messages.each do |log_line|
      refute log_line.include?(message.content),
        "Logger should not emit message content — found in: #{log_line}"
    end

    assert logged_messages.any? { |l| l.include?("[content redacted]") },
      "Logger should use [content redacted] placeholder instead of actual content"
  end

  private

  # Stubs ActionCable.server.broadcast and returns the captured payload hash.
  def capture_broadcast(channel)
    captured_payload = nil
    ActionCable.server.stub(:broadcast, ->(stream, payload) { captured_payload = payload }) do
      yield
    end
    captured_payload
  end
end
