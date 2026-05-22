require "test_helper"

class Api::V1::UsersControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = create_user(username: "users_ctrl_user", password: "password123")
    @token = ApiToken.create!(name: "Users Test Token - #{SecureRandom.hex(4)}", user: @user, scopes: nil)
    @raw_token = @token.token
    @auth_headers = { "Authorization" => "Bearer #{@raw_token}" }
  end

  # -------------------------
  # GET /api/v1/me
  # -------------------------

  test "me returns current user data" do
    get api_v1_me_path, headers: @auth_headers

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal @user.id, json["id"]
    assert_equal @user.username, json["username"]
    assert_equal @user.role, json["role"]
    assert json.key?("timezone")
    assert json.key?("two_factor_enabled")
    assert json.key?("avatar_url")
    assert_equal @user.avatar_initials, json["avatar_initials"]
    assert_equal @user.avatar_color_index, json["avatar_color_index"]
    assert json.key?("created_at")
  end

  test "me returns correct role for admin user" do
    admin = create_user(username: "admin_ctrl_test", role: "admin", password: "password123")
    admin_token = ApiToken.create!(name: "Admin Test Token - #{SecureRandom.hex(4)}", user: admin, scopes: nil)

    get api_v1_me_path, headers: { "Authorization" => "Bearer #{admin_token.token}" }

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "admin", json["role"]
  end

  test "me returns nil avatar_url when no avatar attached" do
    get api_v1_me_path, headers: @auth_headers

    assert_response :success
    json = JSON.parse(response.body)
    assert_nil json["avatar_url"]
  end

  test "me requires authentication" do
    get api_v1_me_path

    assert_response :unauthorized
  end

  # -------------------------
  # PATCH /api/v1/me
  # -------------------------

  test "update changes username successfully with current password" do
    patch "/api/v1/me",
          params: { username: "updated_username", current_password: "password123" },
          headers: @auth_headers

    assert_response :success
    json = JSON.parse(response.body)
    assert json["success"]
    assert_equal "updated_username", json["user"]["username"]

    @user.reload
    assert_equal "updated_username", @user.username
  end

  test "update rejects username change without current password" do
    patch "/api/v1/me",
          params: { username: "hacker_username" },
          headers: @auth_headers

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_equal false, json["success"]
    assert_match /current password is required/i, json["error"]

    @user.reload
    assert_equal "users_ctrl_user", @user.username
  end

  test "update rejects username change with wrong current password" do
    patch "/api/v1/me",
          params: { username: "hacker_username", current_password: "wrongpass" },
          headers: @auth_headers

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_equal false, json["success"]
    assert_match /current password is incorrect/i, json["error"]

    @user.reload
    assert_equal "users_ctrl_user", @user.username
  end

  test "update changes timezone successfully" do
    patch "/api/v1/me",
          params: { timezone: "Eastern Time (US & Canada)" },
          headers: @auth_headers

    assert_response :success
    json = JSON.parse(response.body)
    assert json["success"]
    assert_equal @user.avatar_initials, json["user"]["avatar_initials"]
    assert_equal @user.avatar_color_index, json["user"]["avatar_color_index"]

    @user.reload
    assert_equal "Eastern Time (US & Canada)", @user.timezone
  end

  test "update rejects invalid timezone" do
    patch "/api/v1/me",
          params: { timezone: "Not/AReal/Timezone" },
          headers: @auth_headers

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_equal false, json["success"]
    assert json["errors"].any?
  end

  test "update rejects username that is too short" do
    patch "/api/v1/me",
          params: { username: "ab", current_password: "password123" },
          headers: @auth_headers

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_equal false, json["success"]
    assert json["errors"].any?
  end

  test "update rejects username already taken" do
    other_user = create_user(username: "already_taken_user", password: "password123")

    patch "/api/v1/me",
          params: { username: other_user.username, current_password: "password123" },
          headers: @auth_headers

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_equal false, json["success"]
  end

  test "update requires authentication" do
    patch "/api/v1/me", params: { username: "hacker" }

    assert_response :unauthorized
  end

  # -------------------------
  # POST /api/v1/me/change_password
  # -------------------------

  test "change_password succeeds with correct current password" do
    post api_v1_me_change_password_path,
         params: {
           current_password: "password123",
           new_password: "newpassword456",
           new_password_confirmation: "newpassword456"
         },
         headers: @auth_headers

    assert_response :success
    json = JSON.parse(response.body)
    assert json["success"]

    @user.reload
    assert @user.authenticate("newpassword456"), "New password should authenticate"
  end

  test "change_password rejects wrong current password" do
    post api_v1_me_change_password_path,
         params: {
           current_password: "wrongpassword",
           new_password: "newpassword456",
           new_password_confirmation: "newpassword456"
         },
         headers: @auth_headers

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_equal false, json["success"]
    assert_match /incorrect/i, json["error"]
  end

  test "change_password rejects blank current_password" do
    post api_v1_me_change_password_path,
         params: {
           current_password: "",
           new_password: "newpassword456",
           new_password_confirmation: "newpassword456"
         },
         headers: @auth_headers

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_equal false, json["success"]
  end

  test "change_password rejects blank new_password" do
    post api_v1_me_change_password_path,
         params: {
           current_password: "password123",
           new_password: "",
           new_password_confirmation: ""
         },
         headers: @auth_headers

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_equal false, json["success"]
  end

  test "change_password rejects mismatched confirmation" do
    post api_v1_me_change_password_path,
         params: {
           current_password: "password123",
           new_password: "newpassword456",
           new_password_confirmation: "differentpassword"
         },
         headers: @auth_headers

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_equal false, json["success"]
  end

  test "change_password requires authentication" do
    post api_v1_me_change_password_path,
         params: {
           current_password: "password123",
           new_password: "newpassword456",
           new_password_confirmation: "newpassword456"
         }

    assert_response :unauthorized
  end

  # -------------------------
  # DELETE /api/v1/me/avatar
  # -------------------------

  test "remove_avatar returns error when no avatar attached" do
    delete api_v1_me_avatar_path, headers: @auth_headers

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_equal false, json["success"]
    assert_match /no avatar/i, json["error"]
  end

  test "remove_avatar requires authentication" do
    delete api_v1_me_avatar_path

    assert_response :unauthorized
  end
end
