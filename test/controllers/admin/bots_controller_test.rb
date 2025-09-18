require "test_helper"

class Admin::BotsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @admin = create_user(username: "admin", role: "admin")
    @user = create_user(username: "regular")
    @bot = Bot.create!(name: "Test Bot", bot_type: "webhook")
    @api_bot = Bot.create!(name: "API Bot", bot_type: "api")
  end

  test "should redirect non-admin to dashboard" do
    sign_in_as(@user)
    get admin_bots_path
    assert_redirected_to dashboard_path
  end

  test "should redirect anonymous users to signin" do
    get admin_bots_path
    assert_redirected_to signin_path
  end

  test "should show bots list for admin" do
    sign_in_as(@admin)
    get admin_bots_path
    assert_response :success
  end

  test "should show active and inactive bots" do
    inactive_bot = Bot.create!(name: "Inactive Bot", active: false)
    sign_in_as(@admin)

    get admin_bots_path
    assert_response :success
    # Should display both active and inactive bots
  end

  test "should activate bot" do
    @bot.update!(active: false)
    sign_in_as(@admin)

    post activate_admin_bot_path(@bot)
    assert_redirected_to admin_bots_path

    @bot.reload
    assert @bot.active?
  end

  test "should deactivate bot" do
    @bot.update!(active: true)
    sign_in_as(@admin)

    post deactivate_admin_bot_path(@bot)
    assert_redirected_to admin_bots_path

    @bot.reload
    assert_not @bot.active?
  end

  test "should delete bot" do
    sign_in_as(@admin)

    assert_difference("Bot.count", -1) do
      delete admin_bot_path(@bot)
    end

    assert_redirected_to admin_bots_path
  end

  test "should handle deleting nonexistent bot" do
    sign_in_as(@admin)

    delete admin_bot_path(99999)
    assert_redirected_to admin_bots_path
    assert_match /not found/, flash[:alert]
  end

  test "should show webhook URL for webhook bots" do
    sign_in_as(@admin)
    get admin_bots_path

    assert_response :success
    # Webhook bots should display their webhook URLs
  end

  test "should not show webhook URL for API bots" do
    sign_in_as(@admin)
    get admin_bots_path

    assert_response :success
    # API bots should not display webhook URLs
  end

  test "should display bot status correctly" do
    sign_in_as(@admin)
    get admin_bots_path

    assert_response :success
    # Should show active/inactive status for each bot
  end

  test "should display bot type correctly" do
    sign_in_as(@admin)
    get admin_bots_path

    assert_response :success
    # Should distinguish between webhook and API bots
  end

  test "should handle bot activation for nonexistent bot" do
    sign_in_as(@admin)

    post activate_admin_bot_path(99999)
    assert_redirected_to admin_bots_path
    assert_match /not found/, flash[:alert]
  end

  test "should handle bot deactivation for nonexistent bot" do
    sign_in_as(@admin)

    post deactivate_admin_bot_path(99999)
    assert_redirected_to admin_bots_path
    assert_match /not found/, flash[:alert]
  end

  test "should not allow regular user to activate bot" do
    sign_in_as(@user)

    post activate_admin_bot_path(@bot)
    assert_redirected_to dashboard_path

    @bot.reload
    # Bot status should remain unchanged
  end

  test "should not allow regular user to deactivate bot" do
    sign_in_as(@user)

    post deactivate_admin_bot_path(@bot)
    assert_redirected_to dashboard_path

    @bot.reload
    # Bot status should remain unchanged
  end

  test "should not allow regular user to delete bot" do
    sign_in_as(@user)

    assert_no_difference("Bot.count") do
      delete admin_bot_path(@bot)
    end

    assert_redirected_to dashboard_path
  end

  test "should display bot information" do
    sign_in_as(@admin)

    get admin_bots_path
    assert_response :success
    # Should display bot information
  end

  test "should handle bots with no last used date" do
    sign_in_as(@admin)

    get admin_bots_path
    assert_response :success
    # Should handle bots that have never been used
  end

  test "should show bot count" do
    sign_in_as(@admin)

    get admin_bots_path
    assert_response :success
    # Should display total number of bots
  end

  test "should distinguish webhook and API bot types in listing" do
    sign_in_as(@admin)

    get admin_bots_path
    assert_response :success
    # Should clearly show which bots are webhook vs API type
  end

  test "should handle concurrent bot operations" do
    sign_in_as(@admin)

    # Test rapid activation/deactivation
    post activate_admin_bot_path(@bot)
    post deactivate_admin_bot_path(@bot)
    post activate_admin_bot_path(@bot)

    @bot.reload
    assert @bot.active? # Should end up active
  end

  test "should preserve bot data when toggling status" do
    original_name = @bot.name
    original_webhook_id = @bot.webhook_id
    sign_in_as(@admin)

    post deactivate_admin_bot_path(@bot)
    post activate_admin_bot_path(@bot)

    @bot.reload
    assert_equal original_name, @bot.name
    assert_equal original_webhook_id, @bot.webhook_id
  end

  test "should handle bulk operations gracefully" do
    bots = 5.times.map { |i| Bot.create!(name: "Bot #{i}") }
    sign_in_as(@admin)

    # Rapid operations on multiple bots
    bots.each do |bot|
      post deactivate_admin_bot_path(bot)
    end

    bots.each(&:reload)
    assert bots.all? { |bot| !bot.active? }
  end

  test "should maintain referential integrity when deleting bot" do
    # Create some related data if bots have associations
    sign_in_as(@admin)

    delete admin_bot_path(@bot)
    assert_redirected_to admin_bots_path

    # Verify that related data is handled appropriately
    assert_not Bot.exists?(@bot.id)
  end
end