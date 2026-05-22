require "test_helper"

class Admin::IntegrationsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @admin = create_user(username: "integration_admin_#{SecureRandom.hex(3)}", role: "admin")
    @user = create_user(username: "integration_user_#{SecureRandom.hex(3)}")
  end

  test "redirects anonymous users to signin" do
    get admin_integrations_test_connection_path

    assert_redirected_to signin_path
  end

  test "redirects non-admin users away from integration diagnostics" do
    sign_in_as(@user)

    get admin_integrations_test_connection_path

    assert_redirected_to dashboard_path
  end

  test "returns error when no active api tokens exist" do
    ApiToken.update_all(active: false)
    sign_in_as(@admin)

    get admin_integrations_test_connection_path

    assert_response :ok
    json = JSON.parse(response.body)
    assert_equal "error", json["status"]
    assert_match /No active API tokens/, json["message"]
  end

  test "returns success when persisted active api token exists" do
    ApiToken.create!(name: "Persisted token #{SecureRandom.hex(3)}", user: @admin, active: true, scopes: nil)
    sign_in_as(@admin)

    get admin_integrations_test_connection_path

    assert_response :ok
    json = JSON.parse(response.body)
    assert_equal "success", json["status"]
    assert_equal true, json.dig("details", "api_enabled")
    assert_operator json.dig("details", "active_tokens"), :>=, 1
  end
end
