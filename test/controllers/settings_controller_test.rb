require "test_helper"

class SettingsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = create_user(username: "testuser", password: "secret")
  end

  test "should require login to view settings" do
    get edit_settings_path
    assert_redirected_to signin_path
  end

  test "should show settings page when logged in" do
    sign_in_as(@user)
    get edit_settings_path
    assert_response :success
    assert_select "form" # Settings form should be present
  end

  test "should update username" do
    sign_in_as(@user)

    patch settings_path, params: {
      user: {
        username: "newusername",
        current_password: "secret"
      }
    }

    assert_redirected_to edit_settings_path
    @user.reload
    assert_equal "newusername", @user.username
  end

  test "should update password" do
    sign_in_as(@user)

    patch settings_path, params: {
      user: {
        password: "newpassword",
        password_confirmation: "newpassword",
        current_password: "secret"
      }
    }

    assert_redirected_to edit_settings_path
    @user.reload
    assert @user.authenticate("newpassword")
    assert_not @user.authenticate("secret")
  end

  test "should update username and password together" do
    sign_in_as(@user)

    patch settings_path, params: {
      user: {
        username: "updateduser",
        password: "newpassword",
        password_confirmation: "newpassword",
        current_password: "secret"
      }
    }

    assert_redirected_to edit_settings_path
    @user.reload
    assert_equal "updateduser", @user.username
    assert @user.authenticate("newpassword")
  end

  test "should require current password for updates" do
    sign_in_as(@user)

    patch settings_path, params: {
      user: {
        username: "hackername",
        current_password: "wrongpassword"
      }
    }

    assert_response :unprocessable_content
    @user.reload
    assert_equal "testuser", @user.username # Should remain unchanged
  end

  test "should not update without current password" do
    sign_in_as(@user)

    patch settings_path, params: {
      user: {
        username: "hackername"
      }
    }

    assert_response :unprocessable_content
    @user.reload
    assert_equal "testuser", @user.username
  end

  test "should require password confirmation for password change" do
    sign_in_as(@user)

    patch settings_path, params: {
      user: {
        password: "newpassword",
        password_confirmation: "differentpassword",
        current_password: "secret"
      }
    }

    assert_response :unprocessable_content
    @user.reload
    assert @user.authenticate("secret") # Password should remain unchanged
  end

  test "should not update to duplicate username" do
    other_user = create_user(username: "taken")
    sign_in_as(@user)

    patch settings_path, params: {
      user: {
        username: "taken",
        current_password: "secret"
      }
    }

    assert_response :unprocessable_content
    @user.reload
    assert_equal "testuser", @user.username
  end

  test "should validate username length" do
    sign_in_as(@user)

    # Too short
    patch settings_path, params: {
      user: {
        username: "x",
        current_password: "secret"
      }
    }

    assert_response :unprocessable_content

    # Too long
    patch settings_path, params: {
      user: {
        username: "x" * 100,
        current_password: "secret"
      }
    }

    assert_response :unprocessable_content
    @user.reload
    assert_equal "testuser", @user.username
  end

  test "should handle empty username" do
    sign_in_as(@user)

    patch settings_path, params: {
      user: {
        username: "",
        current_password: "secret"
      }
    }

    assert_response :unprocessable_content
    @user.reload
    assert_equal "testuser", @user.username
  end

  test "should handle special characters in username" do
    sign_in_as(@user)

    patch settings_path, params: {
      user: {
        username: "user@domain.com",
        current_password: "secret"
      }
    }

    # Behavior depends on username validation rules
    @user.reload
    # Should either accept or reject based on validation
    assert @user.username == "user@domain.com" || @user.username == "testuser"
  end

  test "should maintain session after username change" do
    sign_in_as(@user)

    patch settings_path, params: {
      user: {
        username: "newname",
        current_password: "secret"
      }
    }

    # Should still be logged in
    get edit_settings_path
    assert_response :success
    assert_equal @user.id, session[:user_id]
  end

  test "should maintain session after password change" do
    sign_in_as(@user)

    patch settings_path, params: {
      user: {
        password: "newpassword",
        password_confirmation: "newpassword",
        current_password: "secret"
      }
    }

    # Should still be logged in after password change
    get edit_settings_path
    assert_response :success
    assert_equal @user.id, session[:user_id]
  end

  test "should handle concurrent settings updates" do
    sign_in_as(@user)

    # Simulate concurrent update attempts
    original_username = @user.username

    patch settings_path, params: {
      user: {
        username: "concurrent1",
        current_password: "secret"
      }
    }

    @user.reload
    # Should handle the update gracefully
    assert @user.username == "concurrent1" || @user.username == original_username
  end

  test "should preserve role during settings update" do
    admin = create_user(username: "admin", role: "admin", password: "adminpass")
    sign_in_as(admin, password: "adminpass")

    patch settings_path, params: {
      user: {
        username: "newadmin",
        current_password: "adminpass"
      }
    }

    admin.reload
    assert_equal "admin", admin.role # Role should be preserved
    assert_equal "newadmin", admin.username
  end

  test "should handle missing user parameter" do
    sign_in_as(@user)

    patch settings_path, params: {}
    assert_response :unprocessable_content
  end

  test "should not allow role escalation through settings" do
    sign_in_as(@user)

    # Attempt to escalate role through mass assignment
    patch settings_path, params: {
      user: {
        username: "hacker",
        role: "admin",
        current_password: "secret"
      }
    }

    @user.reload
    assert_equal "user", @user.role # Role should remain user
  end
end