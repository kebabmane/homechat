require "test_helper"

class UserSettingsFlowTest < ActionDispatch::IntegrationTest
  test "user updates username and password" do
    user = create_user(username: "before", password: "password123")
    sign_in_as(user)

    patch settings_path, params: { user: { username: "after", password: "newpassword456", password_confirmation: "newpassword456", current_password: "password123" } }
    assert_response :redirect
    follow_redirect!
    assert_response :success
    assert_match /Settings updated successfully/i, @response.body

    # Ensure username changed and new password works
    user.reload
    assert_equal "after", user.username

    delete signout_path
    follow_redirect!
    post signin_path, params: { username: "after", password: "newpassword456" }
    assert_response :redirect
  end

  test "user can update timezone without current password" do
    user = create_user(username: "timezone_user", password: "password123")
    user.update!(timezone: "UTC")
    sign_in_as(user)

    patch settings_path, params: { user: { timezone: "Melbourne" } }

    assert_response :redirect
    user.reload
    assert_equal "Melbourne", user.timezone
  end

  test "username change still requires current password" do
    user = create_user(username: "reauth_user", password: "password123")
    sign_in_as(user)

    patch settings_path, params: { user: { username: "reauth_after" } }

    assert_response :unprocessable_content
    user.reload
    assert_equal "reauth_user", user.username
  end
end
