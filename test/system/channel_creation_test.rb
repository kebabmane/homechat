require "application_system_test_case"

class ChannelCreationTest < ApplicationSystemTestCase
  def sign_in(username: "maker", password: "secret")
    User.find_or_create_by!(username: username) do |u|
      u.password = password
      u.password_confirmation = password
    end
    visit signin_path
    fill_in "Username", with: username
    fill_in "Password", with: password
    click_on "Sign In"
  end

  test "create a new public channel" do
    sign_in
    visit new_channel_path
    fill_in "Channel Name", with: "family-room"
    click_on "Create Channel"
    assert_text "#family-room"
  end
end

