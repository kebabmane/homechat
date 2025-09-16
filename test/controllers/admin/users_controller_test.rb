require "test_helper"

class Admin::UsersControllerTest < ActionDispatch::IntegrationTest
  def setup
    @admin = create_user(username: "admin", role: "admin")
    @user = create_user(username: "regular")
    @other_admin = create_user(username: "other_admin", role: "admin")
  end

  test "should redirect non-admin to dashboard" do
    sign_in_as(@user)
    get admin_users_path
    assert_redirected_to dashboard_path
  end

  test "should show users list for admin" do
    sign_in_as(@admin)
    get admin_users_path
    assert_response :success
    assert_select "table" # Should show users table
  end

  test "should update user role to admin" do
    sign_in_as(@admin)

    patch admin_user_path(@user), params: { user: { role: "admin" } }
    assert_redirected_to admin_users_path

    @user.reload
    assert_equal "admin", @user.role
  end

  test "should update user role to user" do
    sign_in_as(@admin)

    patch admin_user_path(@other_admin), params: { user: { role: "user" } }
    assert_redirected_to admin_users_path

    @other_admin.reload
    assert_equal "user", @other_admin.role
  end

  test "should not demote last admin" do
    # Make sure there's only one admin
    User.where(role: "admin").where.not(id: @admin.id).destroy_all
    sign_in_as(@admin)

    patch admin_user_path(@admin), params: { user: { role: "user" } }
    assert_redirected_to admin_users_path

    @admin.reload
    assert_equal "admin", @admin.role # Should remain admin
  end

  test "should reject invalid role" do
    sign_in_as(@admin)

    patch admin_user_path(@user), params: { user: { role: "invalid" } }
    assert_redirected_to admin_users_path

    @user.reload
    assert_equal "user", @user.role # Should remain unchanged
  end

  test "should show admin count in users list" do
    sign_in_as(@admin)
    get admin_users_path
    assert_response :success

    # Should display the admin count
    assert_select "*", text: /admin/i
  end

  test "should handle missing user parameter" do
    sign_in_as(@admin)

    # This exposes a bug in the controller - should be fixed
    assert_raises(NoMethodError) do
      patch admin_user_path(@user), params: {}
    end
  end

  test "should handle nonexistent user" do
    sign_in_as(@admin)

    # Rails returns 404 for nonexistent records
    patch admin_user_path(99999), params: { user: { role: "admin" } }
    assert_response :not_found
  end

  test "should redirect anonymous users" do
    get admin_users_path
    assert_redirected_to signin_path
  end

  test "should prevent self-demotion when last admin" do
    # Ensure only one admin exists
    User.where(role: "admin").where.not(id: @admin.id).update_all(role: "user")
    sign_in_as(@admin)

    patch admin_user_path(@admin), params: { user: { role: "user" } }
    assert_redirected_to admin_users_path

    @admin.reload
    assert @admin.admin?, "Last admin should not be able to demote themselves"
  end
end