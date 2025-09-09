require "application_system_test_case"

class AuthenticationFlowTest < ApplicationSystemTestCase
  test "sign up then lands on dashboard" do
    visit root_path
    click_on "Get Started"

    username = "sysuser#{SecureRandom.hex(3)}"
    fill_in "Username", with: username
    fill_in "Password", with: "secret"
    fill_in "Confirm Password", with: "secret"
    click_on "Create Account"

    assert_text "Dashboard"
  end

  test "sign in with existing account" do
    user = User.create!(username: "syslogin", password: "secret", password_confirmation: "secret")
    visit signin_path
    fill_in "Username", with: user.username
    fill_in "Password", with: "secret"
    click_on "Sign In"
    assert_text "Dashboard"
  end
end

