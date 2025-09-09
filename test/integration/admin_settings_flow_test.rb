require "test_helper"

class AdminSettingsFlowTest < ActionDispatch::IntegrationTest
  test "admin can update server settings and disable signups" do
    admin = create_user(username: "admin", role: "admin")

    # Sign in as admin
    sign_in_as(admin)

    # Update settings
    patch admin_settings_path, params: { site_name: "My Hub", allow_signups: "0" }
    assert_response :redirect
    follow_redirect!
    assert_response :success

    assert_equal "My Hub", Setting.fetch(:site_name)
    assert_equal false, ActiveModel::Type::Boolean.new.cast(Setting.fetch(:allow_signups))

    # Verify signups disabled
    get signup_path
    assert_response :redirect
    follow_redirect!
    assert_response :success
    assert_match /Sign ups are disabled/i, @response.body
  end
end
