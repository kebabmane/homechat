require "test_helper"

class Api::V1::HealthControllerTest < ActionDispatch::IntegrationTest
  test "health endpoint is public and exposes client capability basics" do
    get "/api/v1/health"

    assert_response :ok
    json = JSON.parse(response.body)
    assert_equal "ok", json["status"]
    assert_equal "HomeChat", json["service"]
    assert_equal "1.0.0", json["api_version"]
    assert json.key?("push_enabled")
    assert_nothing_raised { Time.iso8601(json["timestamp"]) }
    assert_openapi_response "/health"
  end
end
