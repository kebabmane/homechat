require "test_helper"

class Api::V1::ServerInfoControllerTest < ActionDispatch::IntegrationTest
  def setup
    Setting.set(:allow_signups, true)
  end

  test "server_info advertises e2ee policy flags" do
    get "/api/v1/server_info"

    assert_response :success
    json = JSON.parse(response.body)

    assert_equal true, json["e2ee_enabled"]
    assert_equal true, json["e2ee_required_private_dm"]
    assert_equal E2eePolicy::REQUIRED_VERSION, json["min_e2ee_version"]
    assert_equal true, json.dig("e2ee_capabilities", "legacy_write_blocked")
    assert_equal true, json.dig("e2ee_capabilities", "bot_posting_blocked")
  end

  test "server_info reflects registration setting" do
    Setting.set(:allow_signups, false)

    get "/api/v1/server_info"

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal false, json["registration_enabled"]
  end

  test "server_info defaults registration to enabled" do
    get "/api/v1/server_info"

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal true, json["registration_enabled"]
  end
end
