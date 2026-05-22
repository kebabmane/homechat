require "test_helper"

class Api::V1::UserKeysControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = create_user(username: "user_keys_#{SecureRandom.hex(3)}")
    @raw_token = ApiToken.create!(name: "User Keys Test Token", user: @user, scopes: nil).token
    @auth_headers = { "Authorization" => "Bearer #{@raw_token}" }
  end

  test "update_hmac_key creates a key record for the current user" do
    assert_difference("UserKey.count", 1) do
      put "/api/v1/me/hmac_key",
          params: { encrypted_hmac_key: "wrapped-key-v1", key_version: "7" },
          headers: @auth_headers
    end

    assert_response :ok
    key = UserKey.find_by!(user: @user)
    assert_equal "wrapped-key-v1", key.encrypted_hmac_key
    assert_equal "7", key.key_version
  end

  test "update_hmac_key updates existing key instead of creating duplicates" do
    UserKey.create!(user: @user, encrypted_hmac_key: "old-key", key_version: "1")

    assert_no_difference("UserKey.count") do
      put "/api/v1/me/hmac_key",
          params: { encrypted_hmac_key: "new-key", key_version: "2" },
          headers: @auth_headers
    end

    assert_response :ok
    key = UserKey.find_by!(user: @user)
    assert_equal "new-key", key.encrypted_hmac_key
    assert_equal "2", key.key_version
  end

  test "update_hmac_key defaults missing key version" do
    put "/api/v1/me/hmac_key",
        params: { encrypted_hmac_key: "wrapped-key" },
        headers: @auth_headers

    assert_response :ok
    assert_equal "1", UserKey.find_by!(user: @user).key_version
  end

  test "update_hmac_key rejects blank encrypted key" do
    assert_no_difference("UserKey.count") do
      put "/api/v1/me/hmac_key",
          params: { encrypted_hmac_key: " " },
          headers: @auth_headers
    end

    assert_response :unprocessable_entity
    assert_equal false, JSON.parse(response.body)["success"]
  end

  test "get_hmac_key returns current user's stored key" do
    UserKey.create!(user: @user, encrypted_hmac_key: "stored-wrapped-key", key_version: "3")

    get "/api/v1/me/hmac_key", headers: @auth_headers

    assert_response :ok
    json = JSON.parse(response.body)
    assert_equal "stored-wrapped-key", json["encrypted_hmac_key"]
    assert_equal "3", json["key_version"]
  end

  test "get_hmac_key returns not found when missing" do
    get "/api/v1/me/hmac_key", headers: @auth_headers

    assert_response :not_found
    assert_equal false, JSON.parse(response.body)["success"]
  end

  test "requires authentication" do
    get "/api/v1/me/hmac_key"

    assert_response :unauthorized
  end
end
