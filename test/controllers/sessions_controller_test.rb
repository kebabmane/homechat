require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "should get signin page" do
    get signin_path
    assert_response :success
    assert_select "form"
  end

  test "should sign in with valid credentials" do
    user = create_user(username: "testuser", password: "password")

    post signin_path, params: { username: "testuser", password: "password" }
    assert_redirected_to dashboard_path
    assert session[:user_id] == user.id
  end

  test "should not sign in with invalid credentials" do
    create_user(username: "testuser", password: "password")

    post signin_path, params: { username: "testuser", password: "wrongpassword" }
    assert_response :unprocessable_content
    assert_nil session[:user_id]
  end

  test "should not sign in with nonexistent user" do
    post signin_path, params: { username: "nonexistent", password: "password" }
    assert_response :unprocessable_content
    assert_nil session[:user_id]
  end

  test "should sign out" do
    user = create_user
    sign_in_as(user)

    delete signout_path
    assert_redirected_to root_path
    assert_nil session[:user_id]
  end

  test "should handle missing username" do
    post signin_path, params: { password: "password" }
    assert_response :unprocessable_content
    assert_nil session[:user_id]
  end

  test "should handle missing password" do
    post signin_path, params: { username: "testuser" }
    assert_response :unprocessable_content
    assert_nil session[:user_id]
  end
end