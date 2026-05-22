require "test_helper"

class Admin::NukesControllerTest < ActionDispatch::IntegrationTest
  def setup
    @admin = create_user(username: "admin_nuke", role: "admin")
    @user = create_user(username: "regular_nuke")
  end

  test "should require admin access" do
    sign_in_as(@user)
    get admin_nuke_path
    assert_redirected_to dashboard_path
  end

  test "should require login" do
    get admin_nuke_path
    assert_redirected_to signin_path
  end

  test "should show nuke page for admin" do
    sign_in_as(@admin)
    get admin_nuke_path
    assert_response :success
  end

  test "should wipe all data with correct confirmation" do
    channel = Channel.create!(name: "nuke-test", channel_type: "public", created_by: @admin)
    channel.add_member(@admin)
    Message.create!(content: "hello", user: @admin, channel: channel)
    @user.update!(fcm_token: "test-fcm-token")
    initial_channel_count = Channel.count
    initial_message_count = Message.count

    sign_in_as(@admin)

    post admin_nuke_path, params: { confirmation: "NUKE" }

    assert_equal 0, Channel.count
    assert_equal 0, Message.count
    assert_nil @user.reload.fcm_token
    assert_redirected_to admin_dashboard_path
    follow_redirect!
    assert_match /All data has been wiped/i, response.body
  end

  test "should reject wipe without confirmation" do
    sign_in_as(@admin)

    assert_no_difference("Channel.count") do
      post admin_nuke_path, params: { confirmation: "wrong" }
    end

    assert_redirected_to admin_nuke_path
    follow_redirect!
    assert_match /Type NUKE to confirm/i, response.body
  end

  test "should reject wipe from non-admin" do
    sign_in_as(@user)

    assert_no_difference("Channel.count") do
      post admin_nuke_path, params: { confirmation: "NUKE" }
    end

    assert_redirected_to dashboard_path
  end

  test "should create audit log entry after nuke" do
    sign_in_as(@admin)

    post admin_nuke_path, params: { confirmation: "NUKE" }

    audit = AuditLog.where(action: "admin.nuke").last
    assert_not_nil audit
    assert_equal @admin.id, audit.user_id
  end
end
