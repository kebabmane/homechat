require "test_helper"

class MessagingFlowTest < ActionDispatch::IntegrationTest
  test "user can sign in, join public channel, and send a message" do
    user = create_user(username: "flowuser", password: "secret")
    owner = create_user(username: "flowowner")
    channel = Channel.create!(name: "flow", created_by: owner, channel_type: "public")

    # Sign in
    sign_in_as(user, password: "secret")

    # Visit channel and post a message
    get channel_path(channel)
    assert_response :success
    assert_difference -> { Message.count }, +1 do
      post channel_messages_path(channel), params: { message: { content: "hi there" } }
    end
    assert_response :redirect
    follow_redirect!
    assert_response :success
  end
end

