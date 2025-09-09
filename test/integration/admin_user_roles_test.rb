require "test_helper"

class AdminUserRolesTest < ActionDispatch::IntegrationTest
  test "admin can promote and cannot demote last admin" do
    admin = create_user(username: "adminroles", role: "admin")
    user = create_user(username: "normal")

    sign_in_as(admin)

    # Promote user to admin
    patch admin_user_path(user), params: { user: { role: "admin" } }
    assert_response :redirect
    follow_redirect!
    assert_response :success
    assert_equal "admin", user.reload.role

    # Attempt to demote the only admin (if we demote admin, there would still be the promoted user)
    # First, demote original admin and ensure at least one admin remains
    patch admin_user_path(admin), params: { user: { role: "user" } }
    assert_response :redirect
    follow_redirect!
    assert_response :success
    assert_equal "user", admin.reload.role

    # Now try to demote the last remaining admin -> should be blocked
    patch admin_user_path(user), params: { user: { role: "user" } }
    assert_response :redirect
    follow_redirect!
    assert_match /Cannot demote the last admin/i, @response.body
    assert_equal "admin", user.reload.role
  end
end

