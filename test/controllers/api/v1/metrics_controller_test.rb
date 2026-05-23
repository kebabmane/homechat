require "test_helper"

class Api::V1::MetricsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @admin = create_user(username: "metrics_admin_#{SecureRandom.hex(3)}", role: "admin")
    @user = create_user(username: "metrics_user_#{SecureRandom.hex(3)}")
    @admin_token = ApiToken.create!(name: "Metrics Admin Token", user: @admin, scopes: nil).token
    @user_token = ApiToken.create!(name: "Metrics User Token", user: @user, scopes: nil).token
  end

  test "health metrics endpoint is public" do
    get "/api/v1/metrics/health"

    assert_response :ok
    json = JSON.parse(response.body)
    assert_equal "ok", json["status"]
    assert json["version"].present?
    assert_nothing_raised { Time.iso8601(json["timestamp"]) }
  end

  test "detailed metrics require admin user" do
    get "/api/v1/metrics", headers: auth_headers(@user_token)

    assert_response :forbidden
    assert_equal "Admin access required", JSON.parse(response.body)["error"]
  end

  test "admin can retrieve detailed metrics as json" do
    channel = Channel.create!(name: "metrics-#{SecureRandom.hex(3)}", channel_type: "public", creator: @admin)
    Message.create!(content: "metrics message", user: @admin, channel: channel)

    get "/api/v1/metrics", headers: auth_headers(@admin_token)

    assert_response :ok
    json = JSON.parse(response.body)
    assert_equal Rails.env, json.dig("application", "environment")
    assert_operator json.dig("users", "total"), :>=, 2
    assert_operator json.dig("channels", "total"), :>=, 1
    assert_operator json.dig("messages", "total"), :>=, 1
    assert json.dig("database", "adapter").present?
  end

  test "admin can retrieve prometheus text metrics" do
    get "/api/v1/metrics", headers: auth_headers(@admin_token).merge("ACCEPT" => "text/plain")

    assert_response :ok
    assert_includes response.media_type, "text/plain"
    assert_includes response.body, "homechat_users_total"
    assert_includes response.body, "homechat_messages_total"
  end

  private

  def auth_headers(token)
    { "Authorization" => "Bearer #{token}" }
  end
end
