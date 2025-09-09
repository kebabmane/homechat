require "application_system_test_case"

class RealtimeUiTest < JsSystemTestCase
  def setup
    @owner = User.create!(username: "ownerjs", password: "secret", password_confirmation: "secret")
    @channel = Channel.create!(name: "jsroom", created_by: @owner, channel_type: "public")
  end

  test "typing indicator appears for other user" do
    Capybara.using_session(:u1) do
      sign_in(username: "alicejs")
      visit channel_path(@channel)
    end
    Capybara.using_session(:u2) do
      sign_in(username: "bobjs")
      visit channel_path(@channel)
    end

    # Type in first user; second should see typing message briefly
    Capybara.using_session(:u1) do
      find("textarea[name='message[content]']").send_keys("hello")
    end

    Capybara.using_session(:u2) do
      assert_selector("[data-message-list-target='header']", text: "is typing", wait: 3)
    end
  end

  test "Newest button appears when scrolled up and hides when at bottom" do
    # Seed some messages
    20.times { |i| Message.create!(content: "msg #{i}", user: @owner, channel: @channel) }

    sign_in(username: "viewer")
    visit channel_path(@channel)

    container = find("[data-message-list-target='container']")
    # Scroll to top to reveal button
    page.execute_script("const el = document.querySelector('[data-message-list-target=\\'container\\']'); el.scrollTop = 0; el.dispatchEvent(new Event('scroll'));")
    assert_selector("[data-message-list-target='scrollButton']", visible: :visible, wait: 2)

    find("[data-message-list-target='scrollButton']").click
    # After clicking, it should hide (we're at bottom)
    assert_selector("[data-message-list-target='scrollButton']", visible: :hidden, wait: 2)
  end
end

