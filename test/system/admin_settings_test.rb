require "application_system_test_case"

class AdminSettingsTest < JsSystemTestCase
  setup do
    @admin = User.create!(username: "settingsadmin", password: "password123", password_confirmation: "password123", role: "admin")
  end

  test "admin settings page shows all consolidated sections" do
    sign_in(username: @admin.username, password: "password123")
    visit edit_admin_settings_path

    # General settings section
    assert_selector "h2", text: "General"
    assert_selector "input[name='site_name']"
    assert_selector "input[name='allow_signups']"

    # PWA settings section
    assert_selector "h3", text: "Progressive Web App"
    assert_selector "input[name='pwa_enabled']"

    # API & Integrations section (consolidated from old Integrations page)
    assert_selector "h3", text: "API & Integrations"
    assert_selector "input[name='api_enabled']"
    assert_selector "input[name='home_assistant_enabled']"
    assert_selector "input[name='webhook_base_url']"

    # LiteLLM section
    assert_selector "h3", text: "AI & LiteLLM"
  end

  test "can toggle API enabled setting" do
    sign_in(username: @admin.username, password: "password123")
    visit edit_admin_settings_path

    # Toggle API enabled checkbox
    checkbox = find("input[name='api_enabled']")
    initial_state = checkbox.checked?

    checkbox.click
    click_on "Save Settings"

    # Verify setting was saved
    visit edit_admin_settings_path
    checkbox = find("input[name='api_enabled']")
    assert_equal !initial_state, checkbox.checked?
  end

  test "can toggle Home Assistant enabled setting" do
    sign_in(username: @admin.username, password: "password123")
    visit edit_admin_settings_path

    # Toggle HA enabled checkbox
    checkbox = find("input[name='home_assistant_enabled']")
    initial_state = checkbox.checked?

    checkbox.click
    click_on "Save Settings"

    # Verify setting was saved
    visit edit_admin_settings_path
    checkbox = find("input[name='home_assistant_enabled']")
    assert_equal !initial_state, checkbox.checked?
  end

  test "can update webhook base URL" do
    sign_in(username: @admin.username, password: "password123")
    visit edit_admin_settings_path

    # Update webhook URL
    fill_in "webhook_base_url", with: "http://custom.local:3000"
    click_on "Save Settings"

    # Verify setting was saved
    visit edit_admin_settings_path
    assert_equal "http://custom.local:3000", find("input[name='webhook_base_url']").value
  end

  test "admin nav shows all links including Settings" do
    sign_in(username: @admin.username, password: "password123")
    visit admin_dashboard_path

    # Check all nav links are present
    assert_selector "a", text: "Dashboard"
    assert_selector "a", text: "Settings"
    assert_selector "a", text: "Tokens"
    assert_selector "a", text: "Bots"
    assert_selector "a", text: "Users"
    assert_selector "a", text: "HA Setup"
  end

  test "HA Setup page shows documentation only" do
    sign_in(username: @admin.username, password: "password123")
    visit admin_integrations_path

    # Should show setup documentation
    assert_selector "h2", text: /Home Assistant.*Setup/i

    # Should have links to Settings and Tokens
    assert_selector "a", text: "Settings"
    assert_selector "a", text: "API Tokens"
  end

  test "non-admin cannot access admin settings" do
    regular_user = User.create!(username: "regularuser", password: "password123", password_confirmation: "password123", role: "user")
    sign_in(username: regular_user.username, password: "password123")

    visit edit_admin_settings_path

    # Should show access denied or redirect
    assert_text "Admins only"
  end
end
