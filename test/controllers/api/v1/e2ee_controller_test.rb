require "test_helper"

class Api::V1::E2eeControllerTest < ActionDispatch::IntegrationTest
  def setup
    @member = create_user(username: "e2ee_member_#{SecureRandom.hex(3)}")
    @outsider = create_user(username: "e2ee_outsider_#{SecureRandom.hex(3)}")
    @admin = create_user(username: "e2ee_admin_#{SecureRandom.hex(3)}", role: "admin")

    @member_token = create_token(@member)
    @outsider_token = create_token(@outsider)
    @admin_token = create_token(@admin)

    @private_channel = Channel.create!(
      name: "private-e2ee-#{SecureRandom.hex(3)}",
      channel_type: "private",
      creator: @member
    )
    @private_channel.add_member(@member)

    @public_channel = Channel.create!(
      name: "public-e2ee-#{SecureRandom.hex(3)}",
      channel_type: "public",
      creator: @member
    )
  end

  test "member can request channel key rotation" do
    post "/api/v1/channels/#{@private_channel.id}/rotate_key", headers: auth_headers(@member_token)

    assert_response :ok
    json = JSON.parse(response.body)
    assert_equal true, json["success"]
    assert_equal 1, json["key_epoch"]
    assert_equal true, json["rotation_required"]

    @private_channel.reload
    assert_equal 1, @private_channel.key_epoch
    assert @private_channel.key_rotation_required?
  end

  test "admin can request rotation for a channel they are not a member of" do
    post "/api/v1/channels/#{@private_channel.id}/rotate_key", headers: auth_headers(@admin_token)

    assert_response :ok
    assert @private_channel.reload.key_rotation_required?
  end

  test "non-member cannot rotate private channel keys" do
    assert_no_changes -> { @private_channel.reload.key_epoch } do
      post "/api/v1/channels/#{@private_channel.id}/rotate_key", headers: auth_headers(@outsider_token)
    end

    assert_response :forbidden
  end

  test "public channel rotation status is visible to authenticated users" do
    @public_channel.update!(key_rotation_required: true, key_epoch: 3)

    get "/api/v1/channels/#{@public_channel.id}/key_rotation_status", headers: auth_headers(@outsider_token)

    assert_response :ok
    json = JSON.parse(response.body)
    assert_equal true, json["rotation_required"]
    assert_equal 3, json["epoch"]
  end

  test "private rotation status is limited to members" do
    get "/api/v1/channels/#{@private_channel.id}/key_rotation_status", headers: auth_headers(@outsider_token)

    assert_response :forbidden
  end

  test "member acknowledgement clears rotation requirement" do
    @private_channel.update!(key_rotation_required: true, key_epoch: 2)

    post "/api/v1/channels/#{@private_channel.id}/acknowledge_rotation", headers: auth_headers(@member_token)

    assert_response :ok
    assert_not @private_channel.reload.key_rotation_required?
  end

  test "missing channel returns not found" do
    post "/api/v1/channels/999999/rotate_key", headers: auth_headers(@member_token)

    assert_response :not_found
    assert_equal "channel_not_found", JSON.parse(response.body)["error"]
  end

  private

  def create_token(user)
    ApiToken.create!(name: "E2EE test token #{user.username}", user: user, scopes: nil).token
  end

  def auth_headers(token)
    { "Authorization" => "Bearer #{token}" }
  end
end
