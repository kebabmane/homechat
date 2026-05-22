require "test_helper"

class ApplicationCable::ConnectionTest < ActionCable::Connection::TestCase
  def setup
    @user = create_user(username: "cable_user")
    @token = ApiToken.create!(name: "Cable Token", user: @user, scopes: nil)
    @raw_token = @token.token
  end

  test "connects with valid session" do
    # Simulate a session-based connection
    connect params: {}, session: { user_id: @user.id }

    assert_equal @user, connection.current_user
  end

  test "connects with valid bearer token in Authorization header" do
    connect headers: { "Authorization" => "Bearer #{@raw_token}" }

    assert_equal @user, connection.current_user
  end

  test "rejects valid token in URL query params when no session" do
    assert_reject_connection do
      connect params: { token: @raw_token }
    end
  end

  test "rejects connection with token in URL query params" do
    assert_reject_connection do
      connect params: { token: "invalid_token" }
    end
  end

  test "rejects connection without authentication" do
    assert_reject_connection do
      connect params: {}
    end
  end

  test "rejects connection with invalid token in header" do
    assert_reject_connection do
      connect headers: { "Authorization" => "Bearer invalid_token" }
    end
  end

  test "rejects connection with expired/inactive token in header" do
    @token.update!(active: false)

    assert_reject_connection do
      connect headers: { "Authorization" => "Bearer #{@raw_token}" }
    end
  end

  test "rejects connection with non-existent user session" do
    assert_reject_connection do
      connect params: {}, session: { user_id: 999999 }
    end
  end

  test "prefers session over token when both present" do
    other_user = create_user(username: "other_cable_user")
    other_token = ApiToken.create!(name: "Other Token", user: other_user, scopes: nil)

    # Session should take precedence over Authorization header
    connect headers: { "Authorization" => "Bearer #{other_token.token}" }, session: { user_id: @user.id }

    assert_equal @user, connection.current_user
  end
end
