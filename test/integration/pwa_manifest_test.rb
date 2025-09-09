require "test_helper"

class PwaManifestTest < ActionDispatch::IntegrationTest
  test "manifest reflects server settings" do
    admin = create_user(username: "pwaadmin", role: "admin")
    sign_in_as(admin)

    patch admin_settings_path, params: {
      site_name: "LAN Chat",
      pwa_enabled: "1",
      pwa_short_name: "LAN",
      pwa_theme_color: "#123456",
      pwa_bg_color: "#ffffff",
      pwa_display: "browser"
    }
    assert_response :redirect

    get pwa_manifest_path(format: :json)
    assert_response :success

    data = JSON.parse(@response.body)
    assert_equal "LAN Chat", data["name"]
    assert_equal "LAN", data["short_name"]
    assert_equal "#123456", data["theme_color"]
    assert_equal "browser", data["display"]
  end
end

