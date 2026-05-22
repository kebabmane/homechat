require "test_helper"

class Admin::TokensControllerTest < ActionDispatch::IntegrationTest
  def setup
    @admin = create_user(username: "token_admin_#{SecureRandom.hex(3)}", role: "admin")
    @user = create_user(username: "token_user_#{SecureRandom.hex(3)}")
    @channel = Channel.create!(name: "token-channel-#{SecureRandom.hex(3)}", channel_type: "public", creator: @admin)
    @token = ApiToken.create!(
      name: "Existing Token #{SecureRandom.hex(3)}",
      token_type: "bot",
      scopes: [ "bot:post" ],
      user: @admin
    )
  end

  test "redirects anonymous users to signin" do
    get admin_tokens_path

    assert_redirected_to signin_path
  end

  test "redirects non-admin users away from token management" do
    sign_in_as(@user)

    get admin_tokens_path

    assert_redirected_to dashboard_path
  end

  test "index redirects to admin bots token tab" do
    sign_in_as(@admin)

    get admin_tokens_path

    assert_redirected_to admin_bots_path(tab: "tokens")
  end

  test "admin can create a scoped token with channel assignment" do
    sign_in_as(@admin)

    assert_difference([ "ApiToken.count", "TokenChannelAssignment.count" ], 1) do
      post admin_tokens_path,
           params: {
             api_token: {
               name: "New Token #{SecureRandom.hex(3)}",
               token_type: "bot",
               scopes: [ "bot:post" ]
             },
             channel_ids: [ @channel.id ],
             channel_permissions: { @channel.id.to_s => "write" }
           }
    end

    assert_response :success
    created = ApiToken.order(:created_at).last
    assert_equal @admin, created.user
    assert_equal "bot", created.token_type
    assert_equal [ "bot:post" ], created.scopes
    assert_equal "write", created.token_channel_assignments.find_by!(channel: @channel).permission
    assert_select "#tokenValue", text: created.token
  end

  test "admin create rejects invalid scopes without creating assignments" do
    sign_in_as(@admin)

    assert_no_difference([ "ApiToken.count", "TokenChannelAssignment.count" ]) do
      post admin_tokens_path,
           params: {
             api_token: {
               name: "Bad Token #{SecureRandom.hex(3)}",
               token_type: "bot",
               scopes: [ "root:everything" ]
             },
             channel_ids: [ @channel.id ],
             channel_permissions: { @channel.id.to_s => "manage" }
           }
    end

    assert_redirected_to admin_bots_path(tab: "tokens")
    assert_match /invalid scope/, flash[:alert]
  end

  test "edit lists non-dm channels for assignment" do
    dm = Channel.create!(name: "dm-token-#{SecureRandom.hex(3)}", channel_type: "dm", creator: @admin)

    sign_in_as(@admin)
    get edit_admin_token_path(@token)

    assert_response :success
    assert_includes response.body, @channel.name
    assert_not_includes response.body, dm.name
  end

  test "admin can update token attributes and replace channel assignments" do
    TokenChannelAssignment.create!(api_token: @token, channel: @channel, permission: "read")
    other_channel = Channel.create!(name: "token-other-#{SecureRandom.hex(3)}", channel_type: "private", creator: @admin)

    sign_in_as(@admin)
    patch admin_token_path(@token),
          params: {
            api_token: {
              name: "Updated Token",
              token_type: "user",
              scopes: [ "user:channels" ]
            },
            channel_ids: [ other_channel.id ],
            channel_permissions: { other_channel.id.to_s => "manage" }
          }

    assert_redirected_to admin_bots_path(tab: "tokens")
    @token.reload
    assert_equal "Updated Token", @token.name
    assert_equal "user", @token.token_type
    assert_equal [ "user:channels" ], @token.scopes
    assert_nil @token.token_channel_assignments.find_by(channel: @channel)
    assert_equal "manage", @token.token_channel_assignments.find_by!(channel: other_channel).permission
  end

  test "regenerate changes stored token digest and shows new raw token once" do
    old_digest = @token.token_digest

    sign_in_as(@admin)
    post regenerate_admin_token_path(@token)

    assert_response :success
    @token.reload
    assert_not_equal old_digest, @token.token_digest
    assert_select "#tokenValue" do |elements|
      raw_token = elements.first.text.strip
      assert_equal @token, ApiToken.valid_token?(raw_token)
    end
  end

  test "admin can activate deactivate and delete tokens" do
    sign_in_as(@admin)

    post deactivate_admin_token_path(@token)
    assert_redirected_to admin_bots_path(tab: "tokens")
    assert_not @token.reload.active?

    post activate_admin_token_path(@token)
    assert_redirected_to admin_bots_path(tab: "tokens")
    assert @token.reload.active?

    assert_difference("ApiToken.count", -1) do
      delete admin_token_path(@token)
    end
    assert_redirected_to admin_bots_path(tab: "tokens")
  end
end
