require "test_helper"

class SecurityHeadersTest < ActionDispatch::IntegrationTest
  test "default security headers are present" do
    https!
    get "/signin"

    assert_response :success
    assert_equal "nosniff", response.headers["X-Content-Type-Options"]
    assert_equal "strict-origin-when-cross-origin", response.headers["Referrer-Policy"]
    hsts = Rails.application.config.action_dispatch.default_headers["Strict-Transport-Security"]
    assert_match(/max-age=31536000/, hsts.to_s)
  end
end
