require "test_helper"

class MessagesControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = create_user
    @other_user = create_user(username: "other")
    @channel = Channel.create!(name: "test-channel", channel_type: "public", creator: @user)
    @private_channel = Channel.create!(name: "private-channel", channel_type: "private", creator: @user)
    @channel.add_member(@user)
    @private_channel.add_member(@user)
  end

  test "should require login to create message" do
    post channel_messages_path(@channel), params: { message: { content: "Test message" } }
    assert_redirected_to signin_path
  end

  test "should create message in public channel" do
    sign_in_as(@user)

    assert_difference("Message.count") do
      post channel_messages_path(@channel), params: { message: { content: "Hello world!" } }
    end

    assert_redirected_to channel_path(@channel)
    message = Message.last
    assert_equal "Hello world!", message.content
    assert_equal @user, message.user
    assert_equal @channel, message.channel
  end

  test "should create e2ee message in private channel for member" do
    sign_in_as(@user)

    assert_difference("Message.count") do
      post channel_messages_path(@private_channel), params: {
        message: {
          content: "ignored",
          content_encoding: "e2ee",
          encrypted_content: "{\"v\":\"1\",\"iv\":\"abc\",\"ciphertext\":\"def\"}",
          content_hmac: "hmac-private",
          e2ee_version: "1",
          sender_device_id: "device-web-test"
        }
      }
    end

    assert_redirected_to channel_path(@private_channel)
    message = Message.last
    assert_equal E2eePolicy::PLACEHOLDER_CONTENT, message.content
    assert_equal "e2ee", message.content_encoding
    assert_equal @private_channel, message.channel
  end

  test "should reject plaintext message in private channel for member" do
    sign_in_as(@user)

    assert_no_difference("Message.count") do
      post channel_messages_path(@private_channel), params: { message: { content: "Private plaintext" } }
    end

    assert_response :upgrade_required
  end

  test "should not create message in private channel for non-member" do
    sign_in_as(@other_user)

    assert_no_difference("Message.count") do
      post channel_messages_path(@private_channel), params: { message: { content: "Unauthorized message" } }
    end

    assert_redirected_to channels_path
  end

  test "should not create empty message" do
    sign_in_as(@user)

    assert_no_difference("Message.count") do
      post channel_messages_path(@channel), params: { message: { content: "" } }
    end

    assert_redirected_to channel_path(@channel)
  end

  test "should not create message with only whitespace" do
    sign_in_as(@user)

    assert_no_difference("Message.count") do
      post channel_messages_path(@channel), params: { message: { content: "   \n\t   " } }
    end

    assert_redirected_to channel_path(@channel)
  end

  test "should handle very long messages" do
    sign_in_as(@user)
    long_message = "A" * 5000

    assert_no_difference("Message.count") do
      post channel_messages_path(@channel), params: { message: { content: long_message } }
    end

    assert_redirected_to channel_path(@channel)
  end

  test "should handle messages with special characters" do
    sign_in_as(@user)
    special_message = "Hello! 🎉 This has émojis & spëcial chars < > & \" '"

    assert_difference("Message.count") do
      post channel_messages_path(@channel), params: { message: { content: special_message } }
    end

    message = Message.last
    assert_equal special_message, message.content
  end

  test "should handle concurrent message creation" do
    sign_in_as(@user)

    # Create multiple messages rapidly
    5.times do |i|
      post channel_messages_path(@channel), params: { message: { content: "Message #{i}" } }
    end

    assert_equal 5, @channel.messages.count
  end

  test "should preserve message order by creation time" do
    sign_in_as(@user)

    messages = []
    3.times do |i|
      post channel_messages_path(@channel), params: { message: { content: "Message #{i}" } }
      messages << Message.last
      sleep 0.01 # Ensure different timestamps
    end

    channel_messages = @channel.messages.order(:created_at)
    assert_equal messages.map(&:content), channel_messages.map(&:content)
  end

  test "should handle missing message parameter" do
    sign_in_as(@user)

    assert_no_difference("Message.count") do
      post channel_messages_path(@channel), params: {}
    end

    assert_redirected_to channel_path(@channel)
  end

  test "should handle missing content parameter" do
    sign_in_as(@user)

    assert_no_difference("Message.count") do
      post channel_messages_path(@channel), params: { message: {} }
    end

    assert_redirected_to channel_path(@channel)
  end

  test "should handle nonexistent channel" do
    sign_in_as(@user)

    post channel_messages_path(99999), params: { message: { content: "Test" } }

    # In test environment, Rails might render error pages instead of raising
    # Check for 404 response instead
    assert_response :not_found
  end

  test "should track user activity when posting message" do
    sign_in_as(@user)
    original_time = @user.updated_at

    travel 1.minute do
      post channel_messages_path(@channel), params: { message: { content: "Activity test" } }
    end

    @user.reload
    assert @user.updated_at > original_time, "User activity should be tracked"
  end

  test "should handle SQL injection attempts in message content" do
    sign_in_as(@user)
    malicious_content = "'; DROP TABLE messages; --"

    assert_difference("Message.count") do
      post channel_messages_path(@channel), params: { message: { content: malicious_content } }
    end

    message = Message.last
    assert_equal malicious_content, message.content
    # Ensure messages table still exists
    assert_nothing_raised { Message.count }
  end

  test "should handle XSS attempts in message content" do
    sign_in_as(@user)
    xss_content = "<script>alert('XSS')</script>"

    assert_difference("Message.count") do
      post channel_messages_path(@channel), params: { message: { content: xss_content } }
    end

    message = Message.last
    # Content is stored as-is; XSS protection happens at render time via html_escape
    assert_equal xss_content, message.content
  end

  test "should require login to edit message" do
    message = @channel.messages.create!(content: "Edit me", user: @user)
    get edit_channel_message_path(@channel, message)
    assert_redirected_to signin_path
  end

  test "should render edit form for author" do
    sign_in_as(@user)
    message = @channel.messages.create!(content: "Edit me", user: @user)

    get edit_channel_message_path(@channel, message)
    assert_response :success
    assert_includes response.body, "Save"
  end

  test "should allow author to edit plaintext message" do
    sign_in_as(@user)
    message = @channel.messages.create!(content: "Original", user: @user)

    patch channel_message_path(@channel, message), params: { message: { content: "Updated" } }
    assert_redirected_to channel_path(@channel)

    message.reload
    assert_equal "Updated", message.content
  end

  test "should not allow non-author to edit message" do
    sign_in_as(@other_user)
    message = @channel.messages.create!(content: "Original", user: @user)
    @channel.add_member(@other_user)

    get edit_channel_message_path(@channel, message)
    assert_redirected_to channel_path(@channel)
    assert_equal "You can only edit your own messages.", flash[:alert]

    patch channel_message_path(@channel, message), params: { message: { content: "Hacked" } }
    assert_redirected_to channel_path(@channel)

    message.reload
    assert_equal "Original", message.content
  end

  test "should not allow editing e2ee message" do
    sign_in_as(@user)
    message = @private_channel.messages.create!(
      content: E2eePolicy::PLACEHOLDER_CONTENT,
      content_encoding: "e2ee",
      encrypted_content: '{"v":"1","iv":"abc","ciphertext":"def"}',
      content_hmac: "hmac",
      e2ee_version: "1",
      sender_device_id: "device-web-test",
      user: @user
    )

    patch channel_message_path(@private_channel, message), params: { message: { content: "Updated" } }
    assert_redirected_to channel_path(@private_channel)
    assert_equal "Encrypted messages cannot be edited.", flash[:alert]

    message.reload
    assert_equal E2eePolicy::PLACEHOLDER_CONTENT, message.content
  end

  test "should render edit form on invalid update" do
    sign_in_as(@user)
    message = @channel.messages.create!(content: "Original", user: @user)

    patch channel_message_path(@channel, message), params: { message: { content: "" } }
    assert_response :unprocessable_entity
    assert_includes response.body, "Save"
  end
end
