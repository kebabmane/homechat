require "application_system_test_case"

class MobileResponsiveTest < MobileSystemTestCase
  setup do
    @owner = User.create!(username: "mobileowner", password: "password123", password_confirmation: "password123")
    @channel = Channel.create!(name: "mobile-test", created_by: @owner, channel_type: "public")
  end

  test "sidebar is hidden by default on mobile" do
    sign_in(username: @owner.username, password: "password123")
    visit channel_path(@channel)

    # Sidebar panel should have the translate-x class that hides it
    sidebar = find("[data-sidebar-target='panel']")
    assert_match(/-translate-x-full/, sidebar[:class])
  end

  test "hamburger menu opens sidebar on mobile" do
    sign_in(username: @owner.username, password: "password123")
    visit channel_path(@channel)

    # Find and click hamburger menu
    hamburger = find("button[data-action*='sidebar#open']", match: :first)
    hamburger.click

    # Sidebar should now be visible
    sidebar = find("[data-sidebar-target='panel']")
    assert_match(/translate-x-0/, sidebar[:class])
  end

  test "body scroll is locked when sidebar opens" do
    sign_in(username: @owner.username, password: "password123")
    visit channel_path(@channel)

    # Open sidebar
    hamburger = find("button[data-action*='sidebar#open']", match: :first)
    hamburger.click

    # Body should have overflow-hidden class
    body = find("body")
    assert_match(/overflow-hidden/, body[:class])
  end

  test "backdrop click closes sidebar" do
    sign_in(username: @owner.username, password: "password123")
    visit channel_path(@channel)

    # Open sidebar
    hamburger = find("button[data-action*='sidebar#open']", match: :first)
    hamburger.click

    # Verify sidebar is open
    sidebar = find("[data-sidebar-target='panel']")
    assert_match(/translate-x-0/, sidebar[:class])

    # Click backdrop to close
    backdrop = find("[data-sidebar-target='backdrop']")
    backdrop.click

    # Sidebar should be hidden again
    sleep 0.3 # Wait for animation
    assert_match(/-translate-x-full/, sidebar[:class])

    # Body scroll should be restored
    body = find("body")
    assert_no_match(/overflow-hidden/, body[:class])
  end

  test "settings page shows all sections without tabs on mobile" do
    sign_in(username: @owner.username, password: "password123")
    visit edit_settings_path

    # All sections should be visible (stacked, not tabbed)
    assert_selector "h2", text: "Profile"
    assert_selector "h2", text: "Change Password"
    assert_selector "h2", text: "Preferences"

    # Save button should be visible
    assert_selector "input[type='submit'][value='Save Changes']"
  end
end
