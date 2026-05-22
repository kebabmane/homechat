require "test_helper"

class Api::V1::AuthRefreshTest < ActionDispatch::IntegrationTest
  def setup
    @user = create_user(username: "refresh_user_#{SecureRandom.hex(3)}", password: "secret123")
    @token = ApiToken.create!(
      name: "Test - #{@user.username}",
      user: @user,
      scopes: nil,
      expires_at: 90.days.from_now
    )
    @raw_token = @token.token
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/auth/refresh
  # ---------------------------------------------------------------------------

  test "refresh with valid token returns a new token" do
    post "/api/v1/auth/refresh",
         headers: { "Authorization" => "Bearer #{@raw_token}" }

    assert_response :ok
    json = JSON.parse(response.body)
    assert json["success"]
    assert_not_nil json["token"]
    assert json["token"].length >= 32
  end

  test "refresh issues a token different from the original" do
    post "/api/v1/auth/refresh",
         headers: { "Authorization" => "Bearer #{@raw_token}" }

    json = JSON.parse(response.body)
    assert_not_equal @raw_token, json["token"]
  end

  test "refresh deactivates the old token" do
    post "/api/v1/auth/refresh",
         headers: { "Authorization" => "Bearer #{@raw_token}" }

    assert_response :ok
    @token.reload
    assert_equal false, @token.active
  end

  test "refreshed token expires approximately 90 days from now" do
    post "/api/v1/auth/refresh",
         headers: { "Authorization" => "Bearer #{@raw_token}" }

    assert_response :ok
    json = JSON.parse(response.body)

    # Find the new token via its raw value
    new_raw = json["token"]
    new_token = ApiToken.active.find_each.find do |t|
      begin
        BCrypt::Password.new(t.token_digest) == new_raw
      rescue BCrypt::Errors::InvalidHash
        false
      end
    end

    assert_not_nil new_token, "Could not find the new token in the database"
    assert_in_delta 90.days.from_now.to_i, new_token.expires_at.to_i, 60
  end

  test "refresh without Authorization header returns 401" do
    post "/api/v1/auth/refresh"
    assert_response :unauthorized
  end

  test "refresh with an invalid token returns 401" do
    post "/api/v1/auth/refresh",
         headers: { "Authorization" => "Bearer totally_invalid_token_xyz" }

    assert_response :unauthorized
  end

  test "refresh with an expired token returns 401" do
    expired_token = ApiToken.create!(
      name: "Expired - #{@user.username} - #{SecureRandom.hex(4)}",
      user: @user,
      scopes: nil,
      expires_at: 90.days.from_now
    )
    raw_expired = expired_token.token

    # Force expiry in the past
    expired_token.update_columns(expires_at: 1.day.ago)

    post "/api/v1/auth/refresh",
         headers: { "Authorization" => "Bearer #{raw_expired}" }

    # valid_token? filters out expired tokens, so this returns 401 at authenticate step
    assert_response :unauthorized
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/auth/sessions
  # ---------------------------------------------------------------------------

  test "sessions returns list of active tokens for current user" do
    get "/api/v1/auth/sessions",
        headers: { "Authorization" => "Bearer #{@raw_token}" }

    assert_response :ok
    json = JSON.parse(response.body)
    assert json["success"]
    assert_kind_of Array, json["sessions"]
    assert json["sessions"].length >= 1
  end

  test "sessions includes expected fields for each session" do
    get "/api/v1/auth/sessions",
        headers: { "Authorization" => "Bearer #{@raw_token}" }

    json = JSON.parse(response.body)
    session_entry = json["sessions"].find { |s| s["id"] == @token.id }
    assert_not_nil session_entry
    assert_includes session_entry.keys, "id"
    assert_includes session_entry.keys, "name"
    assert_includes session_entry.keys, "token_prefix"
    assert_includes session_entry.keys, "last_used_at"
    assert_includes session_entry.keys, "expires_at"
    assert_includes session_entry.keys, "created_at"
    assert_includes session_entry.keys, "is_current"
  end

  test "sessions marks the current token with is_current true" do
    get "/api/v1/auth/sessions",
        headers: { "Authorization" => "Bearer #{@raw_token}" }

    json = JSON.parse(response.body)
    current_entry = json["sessions"].find { |s| s["id"] == @token.id }
    assert_not_nil current_entry
    assert current_entry["is_current"]
  end

  test "sessions marks other tokens with is_current false" do
    other_token = ApiToken.create!(
      name: "Other - #{@user.username} - #{SecureRandom.hex(4)}",
      user: @user,
      scopes: nil,
      expires_at: 90.days.from_now
    )

    get "/api/v1/auth/sessions",
        headers: { "Authorization" => "Bearer #{@raw_token}" }

    json = JSON.parse(response.body)
    other_entry = json["sessions"].find { |s| s["id"] == other_token.id }
    assert_not_nil other_entry
    assert_not other_entry["is_current"]
  end

  test "sessions masks the token prefix with trailing dots" do
    get "/api/v1/auth/sessions",
        headers: { "Authorization" => "Bearer #{@raw_token}" }

    json = JSON.parse(response.body)
    current_entry = json["sessions"].find { |s| s["id"] == @token.id }
    assert_match(/\.\.\.$/, current_entry["token_prefix"])
  end

  test "sessions does not include deactivated tokens" do
    dead_token = ApiToken.create!(
      name: "Dead - #{@user.username} - #{SecureRandom.hex(4)}",
      user: @user,
      scopes: nil,
      expires_at: 90.days.from_now
    )
    dead_token.deactivate!

    get "/api/v1/auth/sessions",
        headers: { "Authorization" => "Bearer #{@raw_token}" }

    json = JSON.parse(response.body)
    ids = json["sessions"].map { |s| s["id"] }
    assert_not_includes ids, dead_token.id
  end

  test "sessions does not include another user's tokens" do
    other_user = create_user(username: "other_sess_#{SecureRandom.hex(3)}", password: "password123")
    other_user_token = ApiToken.create!(
      name: "Other User - #{other_user.username}",
      user: other_user,
      scopes: nil,
      expires_at: 90.days.from_now
    )

    get "/api/v1/auth/sessions",
        headers: { "Authorization" => "Bearer #{@raw_token}" }

    json = JSON.parse(response.body)
    ids = json["sessions"].map { |s| s["id"] }
    assert_not_includes ids, other_user_token.id
  end

  test "sessions requires authentication" do
    get "/api/v1/auth/sessions"
    assert_response :unauthorized
  end

  # ---------------------------------------------------------------------------
  # DELETE /api/v1/auth/sessions/:id
  # ---------------------------------------------------------------------------

  test "revoke_session deactivates another session belonging to the current user" do
    other_token = ApiToken.create!(
      name: "Revocable - #{@user.username} - #{SecureRandom.hex(4)}",
      user: @user,
      scopes: nil,
      expires_at: 90.days.from_now
    )

    delete "/api/v1/auth/sessions/#{other_token.id}",
           headers: { "Authorization" => "Bearer #{@raw_token}" }

    assert_response :ok
    json = JSON.parse(response.body)
    assert json["success"]
    other_token.reload
    assert_equal false, other_token.active
  end

  test "revoke_session returns 422 when trying to revoke the current session" do
    delete "/api/v1/auth/sessions/#{@token.id}",
           headers: { "Authorization" => "Bearer #{@raw_token}" }

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_not json["success"]
    assert_match(/cannot revoke your current session/i, json["error"])
  end

  test "revoke_session returns 404 for another user's session" do
    other_user = create_user(username: "revoke_victim_#{SecureRandom.hex(3)}", password: "password123")
    victim_token = ApiToken.create!(
      name: "Victim - #{other_user.username}",
      user: other_user,
      scopes: nil,
      expires_at: 90.days.from_now
    )

    delete "/api/v1/auth/sessions/#{victim_token.id}",
           headers: { "Authorization" => "Bearer #{@raw_token}" }

    assert_response :not_found
    json = JSON.parse(response.body)
    assert_not json["success"]
  end

  test "revoke_session returns 404 for a non-existent session id" do
    delete "/api/v1/auth/sessions/9999999",
           headers: { "Authorization" => "Bearer #{@raw_token}" }

    assert_response :not_found
  end

  test "revoke_session requires authentication" do
    delete "/api/v1/auth/sessions/#{@token.id}"
    assert_response :unauthorized
  end

  # ---------------------------------------------------------------------------
  # complete_signin sets expires_at 90 days out
  # ---------------------------------------------------------------------------

  test "token created by complete_signin via api signin has expires_at 90 days from now" do
    signin_user = create_user(username: "signin_exp_#{SecureRandom.hex(3)}", password: "secret123")

    post "/api/v1/signin", params: { username: signin_user.username, password: "secret123" }

    assert_response :ok
    json = JSON.parse(response.body)
    assert json["success"]

    token_record = ApiToken.find_by("name LIKE ?", "Mobile App - #{signin_user.username}%")
    assert_not_nil token_record
    assert_not_nil token_record.expires_at
    assert_in_delta 90.days.from_now.to_i, token_record.expires_at.to_i, 60
  end
end
