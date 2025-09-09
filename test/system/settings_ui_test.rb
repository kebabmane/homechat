require "application_system_test_case"

class SettingsUiTest < JsSystemTestCase
  test "admin changes site name updates document title" do
    admin = User.create!(username: "adminui", password: "secret", password_confirmation: "secret", role: "admin")
    sign_in(username: admin.username, password: "secret")

    visit edit_admin_settings_path
    # Set new site name
    find("input[name='site_name']").set("My Smart Hub")
    click_on "Save Settings"

    # Navigate to root (public landing still uses authentication layout when signed out,
    # but while signed in, dashboard uses application layout; both read Setting.site_name)
    visit dashboard_path
    assert_includes page.title, "My Smart Hub"
  end

  test "enter-to-send preference toggles composer behavior" do
    owner = User.create!(username: "ownerui", password: "secret", password_confirmation: "secret")
    channel = Channel.create!(name: "prefs", created_by: owner, channel_type: "public")
    user = User.create!(username: "enduser", password: "secret", password_confirmation: "secret")

    sign_in(username: user.username, password: "secret")

    # Turn preference OFF in settings
    visit edit_settings_path
    box = find("[data-preferences-target='enter']", visible: :all)
    box.set(false)

    visit channel_path(channel)
    initial = Message.count
    ta = find("textarea[name='message[content]']")
    ta.set("hello off")
    ta.send_keys(:enter)
    # Give the browser a beat; ensure no submission occurred
    sleep 0.3
    assert_equal initial, Message.count

    # Turn preference ON and verify Enter submits
    visit edit_settings_path
    find("[data-preferences-target='enter']", visible: :all).set(true)

    visit channel_path(channel)
    ta = find("textarea[name='message[content]']")
    ta.set("hello on")
    assert_difference -> { Message.count }, +1 do
      ta.send_keys(:enter)
      assert_selector("#\\#{ActionView::RecordIdentifier.dom_id(channel, :messages)}", text: "hello on", wait: 3)
    end
  end
end
