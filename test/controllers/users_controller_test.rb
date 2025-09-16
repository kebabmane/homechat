require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  test "should get signup page" do
    get signup_path
    assert_response :success
    assert_select "form"
  end

  test "should create user with valid params" do
    assert_difference("User.count") do
      post signup_path, params: {
        user: {
          username: "newuser",
          password: "password",
          password_confirmation: "password"
        }
      }
    end

    assert_redirected_to dashboard_path
    user = User.find_by(username: "newuser")
    assert_not_nil user
    assert session[:user_id] == user.id
  end

  test "should not create user with invalid params" do
    assert_no_difference("User.count") do
      post signup_path, params: {
        user: {
          username: "",
          password: "password",
          password_confirmation: "password"
        }
      }
    end

    assert_response :unprocessable_content
    assert_nil session[:user_id]
  end

  test "should not create user with mismatched passwords" do
    assert_no_difference("User.count") do
      post signup_path, params: {
        user: {
          username: "newuser",
          password: "password",
          password_confirmation: "different"
        }
      }
    end

    assert_response :unprocessable_content
    assert_nil session[:user_id]
  end

  test "should not create user with duplicate username" do
    create_user(username: "existing")

    assert_no_difference("User.count") do
      post signup_path, params: {
        user: {
          username: "existing",
          password: "password",
          password_confirmation: "password"
        }
      }
    end

    assert_response :unprocessable_content
    assert_nil session[:user_id]
  end

  test "should redirect signup when signups disabled" do
    Setting.set(:allow_signups, false)

    get signup_path
    assert_redirected_to signin_path

    post signup_path, params: {
      user: {
        username: "newuser",
        password: "password",
        password_confirmation: "password"
      }
    }
    assert_redirected_to signin_path
  end

  test "first user should become admin" do
    # Ensure no users exist
    User.destroy_all

    post signup_path, params: {
      user: {
        username: "firstuser",
        password: "password",
        password_confirmation: "password"
      }
    }

    user = User.find_by(username: "firstuser")
    assert user.admin?
  end
end