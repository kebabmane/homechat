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
end
