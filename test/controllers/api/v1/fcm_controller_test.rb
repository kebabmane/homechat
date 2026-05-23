require "test_helper"

class Api::V1::FcmControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = create_user(username: "fcm_user_#{SecureRandom.hex(3)}")
    @raw_token = ApiToken.create!(name: "FCM Test Token", user: @user, scopes: nil).token
    @auth_headers = { "Authorization" => "Bearer #{@raw_token}" }
  end

  test "update_token accepts token param and strips whitespace" do
    put "/api/v1/fcm_token", params: { token: "  device-token-123  " }, headers: @auth_headers

    assert_response :ok
    json = JSON.parse(response.body)
    assert_equal true, json["success"]
    assert_equal @user.id, json["user_id"]
    assert_equal "device-token-123", @user.reload.fcm_token
  end

  test "update_token accepts legacy fcm_token param" do
    put "/api/v1/fcm_token", params: { fcm_token: "legacy-token-123" }, headers: @auth_headers

    assert_response :ok
    assert_equal "legacy-token-123", @user.reload.fcm_token
  end

  test "update_token rejects blank token" do
    assert_no_changes -> { @user.reload.fcm_token } do
      put "/api/v1/fcm_token", params: { token: " " }, headers: @auth_headers
    end

    assert_response :bad_request
    assert_equal false, JSON.parse(response.body)["success"]
  end

  test "destroy_token clears the current user's token" do
    @user.update!(fcm_token: "delete-me")

    delete "/api/v1/fcm_token", headers: @auth_headers

    assert_response :ok
    assert_nil @user.reload.fcm_token
  end

  test "requires authentication" do
    put "/api/v1/fcm_token", params: { token: "device-token-123" }

    assert_response :unauthorized
  end
end
