require "test_helper"

class UserSettingsFlowTest < ActionDispatch::IntegrationTest
  test "user updates username and password" do
    user = create_user(username: "before", password: "secret")
    sign_in_as(user)

    patch settings_path, params: { user: { username: "after", password: "newpass", password_confirmation: "newpass", current_password: "secret" } }
    assert_response :redirect
    follow_redirect!
    assert_response :success
    assert_match /Settings updated successfully/i, @response.body

    # Ensure username changed and new password works
    user.reload
    assert_equal "after", user.username

    delete signout_path
    follow_redirect!
    post signin_path, params: { username: "after", password: "newpass" }
    assert_response :redirect
  end
end

