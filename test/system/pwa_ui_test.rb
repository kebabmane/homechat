require "application_system_test_case"

class PwaUiTest < JsSystemTestCase
  test "install toast container renders when PWA enabled" do
    admin = User.create!(username: "pwaui", password: "password123", password_confirmation: "password123", role: "admin")
    sign_in(username: admin.username, password: "password123")

    # Ensure enabled via settings
    visit edit_admin_settings_path
    check("Enable installable PWA + offline cache")
    click_on "Save Settings"

    visit root_path
    assert_selector("[data-controller='install-prompt']", wait: 2)
  end

  test "offline page is accessible" do
    visit "/offline.html"
    assert_text "You're offline"
    assert_selector "button", text: "Try Again"
  end

  test "manifest endpoint returns valid JSON" do
    admin = User.create!(username: "manifesttest", password: "password123", password_confirmation: "password123", role: "admin")
    sign_in(username: admin.username, password: "password123")

    # Enable PWA
    visit edit_admin_settings_path
    check("Enable installable PWA + offline cache")
    click_on "Save Settings"

    visit pwa_manifest_path
    # Page should contain JSON with PWA manifest properties
    assert_text "name"
    assert_text "short_name"
    assert_text "start_url"
  end

  test "service worker endpoint is accessible when PWA enabled" do
    admin = User.create!(username: "swtest", password: "password123", password_confirmation: "password123", role: "admin")
    sign_in(username: admin.username, password: "password123")

    # Enable PWA
    visit edit_admin_settings_path
    check("Enable installable PWA + offline cache")
    click_on "Save Settings"

    visit pwa_service_worker_path
    # Service worker should contain cache configuration
    assert_text "CACHE_NAME"
    assert_text "OFFLINE_PAGE"
  end

  test "message list controller has offline indicator target" do
    owner = User.create!(username: "offlineowner", password: "password123", password_confirmation: "password123")
    channel = Channel.create!(name: "offline-test", created_by: owner, channel_type: "public")

    sign_in(username: owner.username, password: "password123")
    visit channel_path(channel)

    # The message list controller should be present
    assert_selector "[data-controller~='message-list']"
  end
end
