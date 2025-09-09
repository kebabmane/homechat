require "test_helper"
require "capybara/minitest"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  # Fast default driver for non‑JS tests
  driven_by :rack_test

  def sign_in(username: "webuser", password: "secret")
    User.find_or_create_by!(username: username) do |u|
      u.password = password
      u.password_confirmation = password
    end
    visit signin_path
    fill_in "Username", with: username
    fill_in "Password", with: password
    click_on "Sign In"
    assert_text "Dashboard"
  end
end

class JsSystemTestCase < ApplicationSystemTestCase
  # Full browser for JS/Turbo/ActionCable interactions
  driven_by :selenium, using: :headless_chrome, screen_size: [1400, 1400]
end
