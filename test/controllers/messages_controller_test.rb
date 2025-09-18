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

  test "should create message in private channel for member" do
    sign_in_as(@user)

    assert_difference("Message.count") do
      post channel_messages_path(@private_channel), params: { message: { content: "Private message" } }
    end

    assert_redirected_to channel_path(@private_channel)
    message = Message.last
    assert_equal "Private message", message.content
    assert_equal @private_channel, message.channel
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
    assert_equal xss_content, message.content
  end
end