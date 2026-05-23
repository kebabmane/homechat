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

  test "admin can toggle API enabled setting" do
    admin = create_user(username: "apiadmin", role: "admin")
    sign_in_as(admin)

    # Enable API
    patch admin_settings_path, params: { api_enabled: "1" }
    assert_response :redirect
    assert_equal true, ActiveModel::Type::Boolean.new.cast(Setting.fetch(:api_enabled))

    # Disable API
    patch admin_settings_path, params: { api_enabled: "0" }
    assert_response :redirect
    assert_equal false, ActiveModel::Type::Boolean.new.cast(Setting.fetch(:api_enabled))
  end

  test "admin can toggle Home Assistant enabled setting" do
    admin = create_user(username: "haadmin", role: "admin")
    sign_in_as(admin)

    # Enable HA
    patch admin_settings_path, params: { home_assistant_enabled: "1" }
    assert_response :redirect
    assert_equal true, ActiveModel::Type::Boolean.new.cast(Setting.fetch(:home_assistant_enabled))

    # Disable HA
    patch admin_settings_path, params: { home_assistant_enabled: "0" }
    assert_response :redirect
    assert_equal false, ActiveModel::Type::Boolean.new.cast(Setting.fetch(:home_assistant_enabled))
  end

  test "admin can update webhook base URL" do
    admin = create_user(username: "webhookadmin", role: "admin")
    sign_in_as(admin)

    patch admin_settings_path, params: { webhook_base_url: "http://custom.local:8080" }
    assert_response :redirect

    assert_equal "http://custom.local:8080", Setting.fetch(:webhook_base_url)
  end

  test "admin settings page shows all consolidated sections" do
    admin = create_user(username: "viewadmin", role: "admin")
    sign_in_as(admin)

    get edit_admin_settings_path
    assert_response :success

    # Check all sections are present
    assert_match /General/, @response.body
    assert_match /Progressive Web App/, @response.body
    assert_match /API & Integrations/, @response.body
    assert_match /AI & LiteLLM/, @response.body
  end

  test "non-admin cannot access admin settings" do
    regular_user = create_user(username: "regularuser", role: "user")
    sign_in_as(regular_user)

    get edit_admin_settings_path
    assert_response :redirect

    patch admin_settings_path, params: { site_name: "Hacked" }
    assert_response :redirect

    # Setting should not have changed
    assert_not_equal "Hacked", Setting.fetch(:site_name)
  end
end
