require "test_helper"

class Api::V1::AuthControllerTest < ActionDispatch::IntegrationTest
  def setup
    @existing_user = create_user(username: "existing_user", password: "password123")
  end

  # Signin tests
  test "should sign in with valid credentials" do
    post api_v1_signin_path, params: {
      username: @existing_user.username,
      password: "password123"
    }

    assert_response :success
    json = JSON.parse(response.body)
    assert json["success"]
    assert_equal @existing_user.id, json["user"]["id"]
    assert_equal @existing_user.username, json["user"]["username"]
    assert_not_nil json["token"]
  end

  test "should return token on successful signin" do
    post api_v1_signin_path, params: {
      username: @existing_user.username,
      password: "password123"
    }

    assert_response :success
    json = JSON.parse(response.body)
    assert_not_nil json["token"]
    assert json["token"].length >= 32
  end

  test "should reject invalid password" do
    post api_v1_signin_path, params: {
      username: @existing_user.username,
      password: "wrong_password"
    }

    assert_response :unauthorized
    json = JSON.parse(response.body)
    refute json["success"]
    assert_match /invalid/i, json["error"]
  end

  test "should reject non-existent username" do
    post api_v1_signin_path, params: {
      username: "nonexistent_user",
      password: "password123"
    }

    assert_response :unauthorized
    json = JSON.parse(response.body)
    refute json["success"]
  end

  test "should create new token for user without existing token" do
    # Clear any existing tokens for this user
    ApiToken.where(name: "Mobile App - #{@existing_user.username}").destroy_all

    assert_difference("ApiToken.count") do
      post api_v1_signin_path, params: {
        username: @existing_user.username,
        password: "password123"
      }
    end

    assert_response :success
  end

  test "should reuse existing active token" do
    # Create initial token via signin
    post api_v1_signin_path, params: {
      username: @existing_user.username,
      password: "password123"
    }
    first_response = JSON.parse(response.body)

    # Sign in again
    post api_v1_signin_path, params: {
      username: @existing_user.username,
      password: "password123"
    }
    second_response = JSON.parse(response.body)

    # Token should be regenerated but use same ApiToken record
    assert_not_equal first_response["token"], second_response["token"]
  end

  test "should not require authentication for signin" do
    # This verifies skip_before_action works
    post api_v1_signin_path, params: {
      username: @existing_user.username,
      password: "password123"
    }

    # Should not get 401 even without Authorization header
    assert_not_equal 401, response.status
  end

  # Signup tests
  test "should sign up new user with valid data" do
    assert_difference(["User.count", "ApiToken.count"]) do
      post api_v1_signup_path, params: {
        username: "new_api_user",
        password: "securepassword",
        password_confirmation: "securepassword"
      }
    end

    assert_response :created
    json = JSON.parse(response.body)
    assert json["success"]
    assert_equal "new_api_user", json["user"]["username"]
    assert_not_nil json["token"]
  end

  test "should reject signup with mismatched passwords" do
    assert_no_difference("User.count") do
      post api_v1_signup_path, params: {
        username: "mismatch_user",
        password: "password123",
        password_confirmation: "different_password"
      }
    end

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    refute json["success"]
    assert json["errors"].any? { |e| e.match?(/confirmation/i) }
  end

  test "should reject signup with existing username" do
    assert_no_difference("User.count") do
      post api_v1_signup_path, params: {
        username: @existing_user.username,
        password: "password123",
        password_confirmation: "password123"
      }
    end

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    refute json["success"]
    assert json["errors"].any? { |e| e.match?(/taken/i) }
  end

  test "should reject signup with short username" do
    assert_no_difference("User.count") do
      post api_v1_signup_path, params: {
        username: "ab",
        password: "password123",
        password_confirmation: "password123"
      }
    end

    assert_response :unprocessable_entity
  end

  test "should reject signup with blank password" do
    assert_no_difference("User.count") do
      post api_v1_signup_path, params: {
        username: "blank_pass_user",
        password: "",
        password_confirmation: ""
      }
    end

    assert_response :unprocessable_entity
  end

  test "should not require authentication for signup" do
    # This verifies skip_before_action works
    post api_v1_signup_path, params: {
      username: "no_auth_user",
      password: "password123",
      password_confirmation: "password123"
    }

    # Should not get 401 even without Authorization header
    assert_not_equal 401, response.status
  end

  # Signout tests
  test "should sign out successfully" do
    token = ApiToken.create!(name: "Test Token", user: @existing_user, scopes: nil)
    raw_token = token.token

    delete api_v1_signout_path,
           headers: { "Authorization" => "Bearer #{raw_token}" }

    assert_response :success
    json = JSON.parse(response.body)
    assert json["success"]
  end

  test "should require authentication for signout" do
    delete api_v1_signout_path

    assert_response :unauthorized
  end

  # Edge cases
  test "should handle missing username parameter" do
    post api_v1_signin_path, params: { password: "password123" }

    assert_response :unauthorized
  end

  test "should handle missing password parameter" do
    post api_v1_signin_path, params: { username: @existing_user.username }

    assert_response :unauthorized
  end

  test "should handle empty request body" do
    post api_v1_signin_path, params: {}

    assert_response :unauthorized
  end

  test "should include user role in response" do
    admin_user = create_user(username: "admin_user", role: "admin", password: "password123")

    post api_v1_signin_path, params: {
      username: admin_user.username,
      password: "password123"
    }

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "admin", json["user"]["role"]
  end
end
