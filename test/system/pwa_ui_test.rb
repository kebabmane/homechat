require "application_system_test_case"

class PwaUiTest < JsSystemTestCase
  test "install toast container renders when PWA enabled" do
    admin = User.create!(username: "pwaui", password: "secret", password_confirmation: "secret", role: "admin")
    sign_in(username: admin.username, password: "secret")

    # Ensure enabled via settings
    visit edit_admin_settings_path
    check("Enable installable PWA + offline cache")
    click_on "Save Settings"

    visit root_path
    assert_selector("[data-controller='install-prompt']", wait: 2)
  end
end

