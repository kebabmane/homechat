require "test_helper"

class Api::V1::Admin::NukesControllerTest < ActionDispatch::IntegrationTest
  def setup
    @admin = create_user(username: "api_admin_nuke", role: "admin")
    @user = create_user(username: "api_regular_nuke")
  end

  test "admin API token wipes server data with correct confirmation" do
    token = ApiToken.create!(
      name: "nuke-admin-token",
      user: @admin,
      token_type: "admin",
      scopes: [ "admin:*" ]
    ).token

    channel = Channel.create!(name: "api-nuke-test", channel_type: "public", created_by: @admin)
    channel.add_member(@admin)
    Message.create!(content: "hello", user: @admin, channel: channel)
    @user.update!(fcm_token: "test-fcm-token")

    post "/api/v1/admin/nuke",
      params: { confirmation: "NUKE" },
      headers: { "Authorization" => "Bearer #{token}" }

    assert_response :success
    assert_equal 0, Channel.count
    assert_equal 0, Message.count
    assert_nil @user.reload.fcm_token
    assert_not_nil AuditLog.where(action: "admin.nuke", user_id: @admin.id).last
  end

  test "admin nuke API rejects non-admin user" do
    token = ApiToken.create!(
      name: "nuke-user-token",
      user: @user,
      token_type: "user",
      scopes: [ "user:profile" ]
    ).token

    post "/api/v1/admin/nuke",
      params: { confirmation: "NUKE" },
      headers: { "Authorization" => "Bearer #{token}" }

    assert_response :forbidden
  end

  test "admin nuke API requires exact confirmation" do
    token = ApiToken.create!(
      name: "nuke-admin-token-bad-confirmation",
      user: @admin,
      token_type: "admin",
      scopes: [ "admin:*" ]
    ).token

    assert_no_difference("Channel.count") do
      post "/api/v1/admin/nuke",
        params: { confirmation: "wrong" },
        headers: { "Authorization" => "Bearer #{token}" }
    end

    assert_response :unprocessable_entity
  end
end
