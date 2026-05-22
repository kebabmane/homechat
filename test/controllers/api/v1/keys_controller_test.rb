require "test_helper"

class Api::V1::KeysControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = create_user(username: "keys_user_#{SecureRandom.hex(3)}", password: "secret123")
    @token = ApiToken.create!(
      name: "Test - #{@user.username}",
      user: @user,
      scopes: nil,
      expires_at: 90.days.from_now
    )
    @raw_token = @token.token

    @other_user = create_user(username: "keys_other_#{SecureRandom.hex(3)}", password: "secret123")
    @other_token = ApiToken.create!(
      name: "Test - #{@other_user.username}",
      user: @other_user,
      scopes: nil,
      expires_at: 90.days.from_now
    )
    @other_raw_token = @other_token.token

    @user_device_id = "device-#{SecureRandom.hex(6)}"
    @other_device_id = "device-#{SecureRandom.hex(6)}"

    @channel = Channel.create!(
      name: "e2ee_test_#{SecureRandom.hex(3)}",
      channel_type: "public",
      created_by_id: @user.id
    )
    ChannelMembership.create!(channel: @channel, user: @user)
    ChannelMembership.create!(channel: @channel, user: @other_user)
  end

  def auth_headers(token:, device_id: nil)
    headers = { "Authorization" => "Bearer #{token}" }
    headers[E2eePolicy::HEADER_VERSION] = E2eePolicy::REQUIRED_VERSION if device_id
    headers[E2eePolicy::HEADER_DEVICE_ID] = device_id if device_id
    headers
  end

  def key_payload(device_id:, enc_key:, sign_key:, fingerprint:, version: "1")
    {
      device_id: device_id,
      encryption_public_key: enc_key,
      signing_public_key: sign_key,
      key_fingerprint: fingerprint,
      key_version: version
    }
  end

  test "publish_e2ee_key creates a device-scoped key record" do
    payload = key_payload(
      device_id: @user_device_id,
      enc_key: "enc_key_abc",
      sign_key: "sign_key_abc",
      fingerprint: "fp_abc"
    )

    assert_difference("UserE2eeKey.count", 1) do
      put "/api/v1/me/e2ee_key", params: payload, headers: auth_headers(token: @raw_token, device_id: @user_device_id)
    end

    assert_response :ok
    json = JSON.parse(response.body)
    assert_equal @user.id, json["user_id"]
    assert_equal @user_device_id, json["device_id"]
    assert_equal "enc_key_abc", json["encryption_public_key"]
    assert_equal "sign_key_abc", json["signing_public_key"]
    assert_equal "fp_abc", json["key_fingerprint"]
  end

  test "publish_e2ee_key rotation increments counter" do
    UserE2eeKey.create!(
      user: @user,
      device_id: @user_device_id,
      encryption_public_key: "enc_old",
      signing_public_key: "sign_old",
      key_fingerprint: "fp_old",
      key_version: "1",
      published_at: Time.current
    )

    assert_no_difference("UserE2eeKey.count") do
      put "/api/v1/me/e2ee_key",
          params: key_payload(device_id: @user_device_id, enc_key: "enc_new", sign_key: "sign_new", fingerprint: "fp_new", version: "2"),
          headers: auth_headers(token: @raw_token, device_id: @user_device_id)
    end

    assert_response :ok
    key = UserE2eeKey.find_by(user: @user, device_id: @user_device_id)
    assert_equal "fp_new", key.key_fingerprint
    assert_equal 1, key.rotation_count
    assert_not_nil key.last_rotated_at
  end

  test "publish_e2ee_key returns 422 on missing required fields" do
    put "/api/v1/me/e2ee_key",
        params: { device_id: @user_device_id },
        headers: auth_headers(token: @raw_token, device_id: @user_device_id)

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_not json["success"]
  end

  test "get_user_e2ee_key returns device list" do
    UserE2eeKey.create!(
      user: @user,
      device_id: @user_device_id,
      encryption_public_key: "enc_pub",
      signing_public_key: "sign_pub",
      key_fingerprint: "fp_pub",
      key_version: "1",
      published_at: Time.current
    )

    get "/api/v1/users/#{@user.id}/e2ee_key", headers: auth_headers(token: @other_raw_token)

    assert_response :ok
    json = JSON.parse(response.body)
    assert_equal @user.id, json["user_id"]
    assert_kind_of Array, json["devices"]
    assert_equal @user_device_id, json["devices"].first["device_id"]
  end

  test "get_channel_e2ee_keys returns member device keys" do
    UserE2eeKey.create!(
      user: @user,
      device_id: @user_device_id,
      encryption_public_key: "u_enc",
      signing_public_key: "u_sign",
      key_fingerprint: "u_fp",
      key_version: "1",
      published_at: Time.current
    )
    UserE2eeKey.create!(
      user: @other_user,
      device_id: @other_device_id,
      encryption_public_key: "o_enc",
      signing_public_key: "o_sign",
      key_fingerprint: "o_fp",
      key_version: "1",
      published_at: Time.current
    )

    get "/api/v1/channels/#{@channel.id}/e2ee_keys", headers: auth_headers(token: @raw_token)

    assert_response :ok
    json = JSON.parse(response.body)
    assert_equal @channel.id, json["channel_id"]
    assert_equal 2, json["members"].length
  end

  test "submit_key_shares creates signed recipient-device shares" do
    sender_key = UserE2eeKey.create!(
      user: @user,
      device_id: @user_device_id,
      encryption_public_key: "u_enc",
      signing_public_key: "u_sign",
      key_fingerprint: "u_fp",
      key_version: "1",
      published_at: Time.current
    )
    UserE2eeKey.create!(
      user: @other_user,
      device_id: @other_device_id,
      encryption_public_key: "o_enc",
      signing_public_key: "o_sign",
      key_fingerprint: "o_fp",
      key_version: "1",
      published_at: Time.current
    )

    shares = [
      {
        recipient_user_id: @other_user.id,
        recipient_device_id: @other_device_id,
        encrypted_channel_key: "wrapped-key-json",
        signature: "signature-base64",
        sender_device_id: @user_device_id,
        sender_key_fingerprint: sender_key.key_fingerprint,
        key_version: "1"
      }
    ]

    assert_difference("ChannelKeyShare.count", 1) do
      post "/api/v1/channels/#{@channel.id}/key_shares",
           params: { key_shares: shares },
           headers: auth_headers(token: @raw_token, device_id: @user_device_id)
    end

    assert_response :ok
    json = JSON.parse(response.body)
    assert json["success"]

    share = ChannelKeyShare.find_by(channel: @channel, recipient_user_id: @other_user.id, recipient_device_id: @other_device_id)
    assert_equal @user.id, share.sender_user_id
    assert_equal @user_device_id, share.sender_device_id
  end

  test "submit_key_shares rejects non-member recipient" do
    outsider = create_user(username: "outsider_#{SecureRandom.hex(2)}", password: "secret123")
    outsider_device = "device-#{SecureRandom.hex(5)}"

    UserE2eeKey.create!(
      user: @user,
      device_id: @user_device_id,
      encryption_public_key: "u_enc",
      signing_public_key: "u_sign",
      key_fingerprint: "u_fp",
      key_version: "1",
      published_at: Time.current
    )
    UserE2eeKey.create!(
      user: outsider,
      device_id: outsider_device,
      encryption_public_key: "x_enc",
      signing_public_key: "x_sign",
      key_fingerprint: "x_fp",
      key_version: "1",
      published_at: Time.current
    )

    post "/api/v1/channels/#{@channel.id}/key_shares",
         params: {
           key_shares: [ {
             recipient_user_id: outsider.id,
             recipient_device_id: outsider_device,
             encrypted_channel_key: "wrapped",
             signature: "sig",
             sender_device_id: @user_device_id,
             sender_key_fingerprint: "u_fp"
           } ]
         },
         headers: auth_headers(token: @raw_token, device_id: @user_device_id)

    assert_response :unprocessable_entity
  end

  test "get_my_key_share requires matching device id" do
    UserE2eeKey.create!(
      user: @other_user,
      device_id: @other_device_id,
      encryption_public_key: "o_enc",
      signing_public_key: "o_sign",
      key_fingerprint: "o_fp",
      key_version: "1",
      published_at: Time.current
    )

    ChannelKeyShare.create!(
      channel: @channel,
      recipient_user_id: @other_user.id,
      recipient_device_id: @other_device_id,
      sender_user_id: @user.id,
      sender_device_id: @user_device_id,
      sender_key_fingerprint: "u_fp",
      encrypted_channel_key: "encrypted-share",
      signature: "sig",
      key_version: "1"
    )

    get "/api/v1/channels/#{@channel.id}/key_shares/me",
        headers: auth_headers(token: @other_raw_token, device_id: @other_device_id)

    assert_response :ok
    json = JSON.parse(response.body)
    assert_equal "encrypted-share", json["encrypted_channel_key"]
    assert_equal @other_device_id, json["recipient_device_id"]
  end
end
