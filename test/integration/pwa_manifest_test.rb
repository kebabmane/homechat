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

  test "service worker includes offline configuration" do
    admin = create_user(username: "swadmin", role: "admin")
    sign_in_as(admin)

    # Enable PWA
    patch admin_settings_path, params: { pwa_enabled: "1" }
    assert_response :redirect

    get pwa_service_worker_path(format: :js)
    assert_response :success

    # Service worker should include offline fallback
    assert_match /CACHE_NAME/, @response.body
    assert_match /OFFLINE_PAGE/, @response.body
    assert_match /offline\.html/, @response.body
  end

  test "service worker includes cache-busting version" do
    admin = create_user(username: "versionadmin", role: "admin")
    sign_in_as(admin)

    # Enable PWA
    patch admin_settings_path, params: { pwa_enabled: "1" }
    assert_response :redirect

    get pwa_service_worker_path(format: :js)
    assert_response :success

    # Cache name should include version/timestamp
    assert_match /homechat-\d+/, @response.body
  end

  test "offline page is accessible" do
    get "/offline.html"
    assert_response :success
    assert_match /You're offline/, @response.body
    assert_match /Try Again/, @response.body
  end

  test "manifest includes required PWA properties" do
    admin = create_user(username: "propsadmin", role: "admin")
    sign_in_as(admin)

    patch admin_settings_path, params: { pwa_enabled: "1" }
    assert_response :redirect

    get pwa_manifest_path(format: :json)
    assert_response :success

    data = JSON.parse(@response.body)

    # Required PWA properties
    assert data.key?("name"), "Manifest should have name"
    assert data.key?("short_name"), "Manifest should have short_name"
    assert data.key?("start_url"), "Manifest should have start_url"
    assert data.key?("icons"), "Manifest should have icons"
    assert data.key?("display"), "Manifest should have display"
    assert data.key?("theme_color"), "Manifest should have theme_color"
    assert data.key?("background_color"), "Manifest should have background_color"
  end
end
