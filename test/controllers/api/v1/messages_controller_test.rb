require "test_helper"

class Api::V1::MessagesControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = create_user
    @recipient = create_user(username: "recipient")

    @token = ApiToken.create!(name: "Test Token", user: @user, scopes: nil)
    @raw_token = @token.token

    @channel = Channel.create!(name: "api-test-#{SecureRandom.hex(3)}", channel_type: "public", creator: @user)
    @private_channel = Channel.create!(name: "private-test-#{SecureRandom.hex(3)}", channel_type: "private", creator: @user)

    @channel.add_member(@user)
    @private_channel.add_member(@user)
    @private_channel.add_member(@recipient)

    @device_id = "device-#{SecureRandom.hex(6)}"
  end

  def auth_headers(device: nil)
    headers = { "Authorization" => "Bearer #{@raw_token}" }
    if device
      headers[E2eePolicy::HEADER_VERSION] = E2eePolicy::REQUIRED_VERSION
      headers[E2eePolicy::HEADER_DEVICE_ID] = device
    end
    headers
  end

  test "should require authentication" do
    post api_v1_messages_path, params: { message: "Test message" }
    assert_response :unauthorized
  end

  test "should create plaintext message in public channel" do
    assert_difference("Message.count") do
      post api_v1_messages_path,
           params: { message: "Test message", room_id: @channel.name },
           headers: auth_headers
    end

    assert_response :success
    message = Message.last
    assert_equal "plaintext", message.content_encoding
    assert_equal "Test message", message.content
  end

  test "should reject plaintext DM without e2ee headers and payload" do
    assert_no_difference("Message.count") do
      post api_v1_user_messages_path(@recipient),
           params: { message: "Direct plaintext" },
           headers: auth_headers
    end

    assert_response :upgrade_required
    json = JSON.parse(response.body)
    assert_equal E2eePolicy::LEGACY_UPGRADE_ERROR_CODE, json["code"]
  end

  test "should create e2ee DM with required headers and payload" do
    payload = {
      message: {
        content: "ignored-plaintext",
        content_encoding: "e2ee",
        encrypted_content: "{\"v\":\"1\",\"iv\":\"abc\",\"ciphertext\":\"def\"}",
        content_hmac: "hmac-123",
        sender_key_fingerprint: "fp-123"
      }
    }

    assert_difference("Message.count") do
      post api_v1_user_messages_path(@recipient),
           params: payload,
           headers: auth_headers(device: @device_id)
    end

    assert_response :success
    message = Message.last
    assert_equal "e2ee", message.content_encoding
    assert_equal E2eePolicy::PLACEHOLDER_CONTENT, message.content
    assert_equal "hmac-123", message.content_hmac
    assert_equal @device_id, message.sender_device_id
    assert_equal "1", message.e2ee_version
  end

  test "should reject plaintext write to private channel endpoint" do
    assert_no_difference("Message.count") do
      post "/api/v1/channels/#{@private_channel.id}/messages",
           params: { message: "plaintext private" },
           headers: auth_headers
    end

    assert_response :upgrade_required
    json = JSON.parse(response.body)
    assert_equal E2eePolicy::LEGACY_UPGRADE_ERROR_CODE, json["code"]
  end

  test "should create e2ee message in private channel" do
    assert_difference("Message.count") do
      post "/api/v1/channels/#{@private_channel.id}/messages",
           params: {
             message: {
               content: "ignored",
               content_encoding: "e2ee",
               encrypted_content: "{\"v\":\"1\",\"iv\":\"abc\",\"ciphertext\":\"def\"}",
               content_hmac: "hmac-456",
               sender_key_fingerprint: "fp-456"
             }
           },
           headers: auth_headers(device: @device_id)
    end

    assert_response :success
    message = Message.last
    assert_equal "e2ee", message.content_encoding
    assert_equal E2eePolicy::PLACEHOLDER_CONTENT, message.content
  end

  test "should reject media upload in e2ee private channel" do
    assert_no_difference("Message.count") do
      post "/api/v1/channels/#{@private_channel.id}/media",
           params: { caption: "file" },
           headers: auth_headers(device: @device_id)
    end

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_equal "e2ee_files_not_supported", json["code"]
  end

  test "index should include receipt counters without errors" do
    message = Message.create!(content: "Receipt target", user: @recipient, channel: @channel)
    MessageReceipt.create!(message: message, user: @user, status: :delivered)
    MessageReceipt.create!(message: message, user: @recipient, status: :read)

    get api_v1_messages_path,
        params: { channel_id: @channel.id },
        headers: auth_headers

    assert_response :success
    json = JSON.parse(response.body)
    serialized = json["messages"].find { |m| m["id"] == message.id }
    assert_not_nil serialized
    assert_equal 1, serialized.dig("receipts", "delivered_count")
    assert_equal 1, serialized.dig("receipts", "read_count")
  end

  test "dm channels should include unread count and last message data" do
    dm_channel = Channel.create!(
      name: "dm-#{@user.username}-#{@recipient.username}-#{SecureRandom.hex(2)}",
      channel_type: "dm",
      creator: @user
    )
    dm_channel.add_member(@user)
    dm_channel.add_member(@recipient)

    Message.create!(content: "from recipient", user: @recipient, channel: dm_channel)
    Message.create!(content: "from self", user: @user, channel: dm_channel)

    get "/api/v1/dm/channels", headers: auth_headers

    assert_response :success
    json = JSON.parse(response.body)
    channel_json = json["channels"].find { |channel| channel["id"] == dm_channel.id }
    assert_not_nil channel_json
    assert_equal @recipient.username, channel_json["name"]
    assert_equal 1, channel_json["unread_count"]
    assert_equal "from self", channel_json.dig("last_message", "content")
  end

  test "create_media rejects disallowed file types" do
    post media_api_v1_channel_path(@channel),
         params: {
           files: [ Rack::Test::UploadedFile.new(StringIO.new("#!/bin/bash\nevil"), "application/x-sh", original_filename: "evil.sh") ],
           caption: "bad file"
         },
         headers: auth_headers

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert json["errors"].any? { |e| e.include?("unsupported type") }
  end

  test "create_media rejects oversized files" do
    post media_api_v1_channel_path(@channel),
         params: {
           files: [ Rack::Test::UploadedFile.new(StringIO.new("x" * (Message::MAX_FILE_SIZE + 1)), "text/plain", original_filename: "huge.txt") ],
           caption: "big file"
         },
         headers: auth_headers

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert json["errors"].any? { |e| e.include?("must be less than") }
  end

  test "create_media accepts valid image file" do
    assert_difference("Message.count", 1) do
      post media_api_v1_channel_path(@channel),
           params: {
             files: [ Rack::Test::UploadedFile.new(StringIO.new("fake image"), "image/png", original_filename: "photo.png") ],
             caption: "nice photo"
           },
           headers: auth_headers
      assert_response :success
    end
  end
end
