require "test_helper"
require "ed25519"

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

  def signing_pair
    signing_key = Ed25519::SigningKey.generate
    [ Base64.strict_encode64(signing_key.verify_key.to_bytes), signing_key ]
  end

  def raw_key
    Base64.strict_encode64(SecureRandom.random_bytes(32))
  end

  def key_share_blob
    Base64.strict_encode64(SecureRandom.random_bytes(92))
  end

  def fingerprint(enc_key, sign_key)
    E2eePolicy.bundle_fingerprint(enc_key, sign_key)
  end

  def sign_key_share(signing_key, channel:, key_epoch:, recipient_user_id:, recipient_device_id:, recipient_key_fingerprint:, encrypted_channel_key:, sender_device_id:, sender_key_fingerprint:, key_version: "1")
    payload = E2eeSignatureVerifier.key_share_payload(
      channel: channel,
      key_epoch: key_epoch,
      recipient_user_id: recipient_user_id,
      recipient_device_id: recipient_device_id,
      recipient_key_fingerprint: recipient_key_fingerprint,
      encrypted_channel_key: encrypted_channel_key,
      sender_device_id: sender_device_id,
      sender_key_fingerprint: sender_key_fingerprint,
      key_version: key_version
    )
    Base64.strict_encode64(signing_key.sign(payload))
  end

  def create_device_key(user:, device_id:, encryption_public_key: raw_key, signing_public_key: raw_key, signing_key: nil)
    signing_public_key = Base64.strict_encode64(signing_key.verify_key.to_bytes) if signing_key
    UserE2eeKey.create!(
      user: user,
      device_id: device_id,
      encryption_public_key: encryption_public_key,
      signing_public_key: signing_public_key,
      key_fingerprint: fingerprint(encryption_public_key, signing_public_key),
      key_version: "1",
      published_at: Time.current
    )
  end

  test "signature verifier rejects non-raw ed25519 public keys" do
    signing_public_key, signing_key = signing_pair
    payload = "homechat-key-share-v2:test"
    signature = Base64.strict_encode64(signing_key.sign(payload))

    assert E2eeSignatureVerifier.valid_key_share_signature?(
      payload: payload,
      signature: signature,
      signing_public_key: signing_public_key
    )
    assert_not E2eeSignatureVerifier.valid_key_share_signature?(
      payload: payload,
      signature: signature,
      signing_public_key: { kty: "EC", crv: "P-256", x: "x", y: "y" }.to_json
    )
  end

  test "publish_e2ee_key creates a device-scoped key record" do
    enc_key = raw_key
    sign_key = raw_key
    payload = key_payload(
      device_id: @user_device_id,
      enc_key: enc_key,
      sign_key: sign_key,
      fingerprint: "fp_abc"
    )

    assert_difference("UserE2eeKey.count", 1) do
      put "/api/v1/me/e2ee_key", params: payload, headers: auth_headers(token: @raw_token, device_id: @user_device_id)
    end

    assert_response :ok
    json = JSON.parse(response.body)
    assert_equal @user.id, json["user_id"]
    assert_equal @user_device_id, json["device_id"]
    assert_equal enc_key, json["encryption_public_key"]
    assert_equal sign_key, json["signing_public_key"]
    assert_equal fingerprint(enc_key, sign_key), json["key_fingerprint"]
  end

  test "publish_e2ee_key rotation increments counter" do
    enc_old = raw_key
    sign_old = raw_key
    UserE2eeKey.create!(
      user: @user,
      device_id: @user_device_id,
      encryption_public_key: enc_old,
      signing_public_key: sign_old,
      key_fingerprint: fingerprint(enc_old, sign_old),
      key_version: "1",
      published_at: Time.current
    )

    enc_new = raw_key
    sign_new = raw_key
    assert_no_difference("UserE2eeKey.count") do
      put "/api/v1/me/e2ee_key",
          params: key_payload(device_id: @user_device_id, enc_key: enc_new, sign_key: sign_new, fingerprint: "fp_new", version: "2"),
          headers: auth_headers(token: @raw_token, device_id: @user_device_id)
    end

    assert_response :ok
    key = UserE2eeKey.find_by(user: @user, device_id: @user_device_id)
    assert_equal fingerprint(enc_new, sign_new), key.key_fingerprint
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

  test "publish_e2ee_key rejects jwk and wrong length key material" do
    put "/api/v1/me/e2ee_key",
        params: key_payload(
          device_id: @user_device_id,
          enc_key: { kty: "OKP", crv: "X25519", x: "abc" }.to_json,
          sign_key: raw_key,
          fingerprint: "client-fp"
        ),
        headers: auth_headers(token: @raw_token, device_id: @user_device_id)

    assert_response :unprocessable_entity

    put "/api/v1/me/e2ee_key",
        params: key_payload(
          device_id: @user_device_id,
          enc_key: Base64.strict_encode64(SecureRandom.random_bytes(31)),
          sign_key: raw_key,
          fingerprint: "client-fp"
        ),
        headers: auth_headers(token: @raw_token, device_id: @user_device_id)

    assert_response :unprocessable_entity
  end

  test "get_user_e2ee_key returns device list" do
    create_device_key(user: @user, device_id: @user_device_id)

    get "/api/v1/users/#{@user.id}/e2ee_key", headers: auth_headers(token: @other_raw_token)

    assert_response :ok
    json = JSON.parse(response.body)
    assert_equal @user.id, json["user_id"]
    assert_kind_of Array, json["devices"]
    assert_equal @user_device_id, json["devices"].first["device_id"]
  end

  test "get_channel_e2ee_keys returns member device keys" do
    create_device_key(user: @user, device_id: @user_device_id)
    create_device_key(user: @other_user, device_id: @other_device_id)

    get "/api/v1/channels/#{@channel.id}/e2ee_keys", headers: auth_headers(token: @raw_token)

    assert_response :ok
    json = JSON.parse(response.body)
    assert_equal @channel.id, json["channel_id"]
    assert_equal @channel.key_epoch, json["key_epoch"]
    assert_equal 2, json["members"].length
  end

  test "key discovery filters legacy unusable device keys" do
    valid_key = create_device_key(user: @user, device_id: @user_device_id)
    UserE2eeKey.create!(
      user: @user,
      device_id: "legacy-#{SecureRandom.hex(5)}",
      encryption_public_key: { kty: "EC", crv: "P-256", x: "x", y: "y" }.to_json,
      signing_public_key: raw_key,
      key_fingerprint: "legacy-fingerprint",
      key_version: "1",
      published_at: Time.current
    )

    get "/api/v1/users/#{@user.id}/e2ee_key", headers: auth_headers(token: @other_raw_token)

    assert_response :ok
    user_json = JSON.parse(response.body)
    assert_equal [ valid_key.device_id ], user_json["devices"].map { |device| device["device_id"] }

    get "/api/v1/channels/#{@channel.id}/e2ee_keys", headers: auth_headers(token: @raw_token)

    assert_response :ok
    channel_json = JSON.parse(response.body)
    assert_equal [ valid_key.device_id ], channel_json["members"].map { |device| device["device_id"] }
  end

  test "submit_key_shares creates signed recipient-device shares" do
    signing_public_key, signing_key = signing_pair
    sender_encryption_key = raw_key
    sender_fingerprint = fingerprint(sender_encryption_key, signing_public_key)
    sender_key = create_device_key(
      user: @user,
      device_id: @user_device_id,
      encryption_public_key: sender_encryption_key,
      signing_public_key: signing_public_key,
      signing_key: signing_key
    )
    recipient_key = create_device_key(user: @other_user, device_id: @other_device_id)
    encrypted_channel_key = key_share_blob

    shares = [
      {
        recipient_user_id: @other_user.id,
        recipient_device_id: @other_device_id,
        recipient_key_fingerprint: recipient_key.key_fingerprint,
        encrypted_channel_key: encrypted_channel_key,
        signature: sign_key_share(
          signing_key,
          channel: @channel,
          key_epoch: @channel.key_epoch,
          recipient_user_id: @other_user.id,
          recipient_device_id: @other_device_id,
          recipient_key_fingerprint: recipient_key.key_fingerprint,
          encrypted_channel_key: encrypted_channel_key,
          sender_device_id: @user_device_id,
          sender_key_fingerprint: sender_key.key_fingerprint
        ),
        sender_device_id: @user_device_id,
        sender_key_fingerprint: sender_key.key_fingerprint,
        key_epoch: @channel.key_epoch,
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

    sender_key = create_device_key(user: @user, device_id: @user_device_id)
    create_device_key(user: outsider, device_id: outsider_device)

    post "/api/v1/channels/#{@channel.id}/key_shares",
         params: {
           key_shares: [ {
             recipient_user_id: outsider.id,
             recipient_device_id: outsider_device,
             encrypted_channel_key: key_share_blob,
             signature: "sig",
             sender_device_id: @user_device_id,
             sender_key_fingerprint: sender_key.key_fingerprint
           } ]
         },
         headers: auth_headers(token: @raw_token, device_id: @user_device_id)

    assert_response :unprocessable_entity
  end

  test "get_my_key_share requires matching device id" do
    recipient_key = create_device_key(user: @other_user, device_id: @other_device_id)

    ChannelKeyShare.create!(
      channel: @channel,
      recipient_user_id: @other_user.id,
      recipient_device_id: @other_device_id,
      sender_user_id: @user.id,
      sender_device_id: @user_device_id,
      sender_key_fingerprint: "u_fp",
      encrypted_channel_key: key_share_blob,
      signature: "sig",
      key_version: "1"
    )

    get "/api/v1/channels/#{@channel.id}/key_shares/me",
        headers: auth_headers(token: @other_raw_token, device_id: @other_device_id)

    assert_response :ok
    json = JSON.parse(response.body)
    assert_equal @other_device_id, json["recipient_device_id"]
    assert_equal recipient_key.key_fingerprint, json["recipient_key_fingerprint"]
  end
end
