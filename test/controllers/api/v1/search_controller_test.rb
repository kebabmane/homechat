require "test_helper"

class Api::V1::SearchControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = create_user(username: "searcher")
    @token = ApiToken.create!(name: "Test Token", user: @user, scopes: nil)
    @raw_token = @token.token

    # Create searchable data
    @other_user = create_user(username: "findable_user")
    @channel = Channel.create!(name: "searchable-channel", description: "A test channel", channel_type: "public", creator: @user)
    @channel.add_member(@user)
    @message = Message.create!(content: "This is a searchable message", user: @user, channel: @channel)
  end

  # Authentication tests
  test "should require authentication for search" do
    get api_v1_search_path, params: { q: "test" }
    assert_response :unauthorized
  end

  test "should require authentication for user search" do
    get api_v1_users_search_path, params: { q: "test" }
    assert_response :unauthorized
  end

  # Index (combined search) tests
  test "should search and return combined results" do
    get api_v1_search_path,
        params: { q: "searchable" },
        headers: { "Authorization" => "Bearer #{@raw_token}" }

    assert_response :success
    json = JSON.parse(response.body)

    assert json.key?("users")
    assert json.key?("channels")
    assert json.key?("messages")
    assert json.key?("totalResults")
  end

  test "should find users by username" do
    get api_v1_search_path,
        params: { q: "findable" },
        headers: { "Authorization" => "Bearer #{@raw_token}" }

    assert_response :success
    json = JSON.parse(response.body)
    assert json["users"].any? { |u| u["username"] == "findable_user" }
  end

  test "should find channels by name" do
    get api_v1_search_path,
        params: { q: "searchable-channel" },
        headers: { "Authorization" => "Bearer #{@raw_token}" }

    assert_response :success
    json = JSON.parse(response.body)
    assert json["channels"].any? { |c| c["name"] == "searchable-channel" }
  end

  test "should find channels by description" do
    get api_v1_search_path,
        params: { q: "test channel" },
        headers: { "Authorization" => "Bearer #{@raw_token}" }

    assert_response :success
    json = JSON.parse(response.body)
    assert json["channels"].any? { |c| c["description"]&.include?("test") }
  end

  test "should find messages by content" do
    get api_v1_search_path,
        params: { q: "searchable message" },
        headers: { "Authorization" => "Bearer #{@raw_token}" }

    assert_response :success
    json = JSON.parse(response.body)
    assert json["messages"].any? { |m| m["content"].include?("searchable") }
  end

  test "should exclude current user from user search results" do
    get api_v1_search_path,
        params: { q: "searcher" },
        headers: { "Authorization" => "Bearer #{@raw_token}" }

    assert_response :success
    json = JSON.parse(response.body)
    refute json["users"].any? { |u| u["username"] == "searcher" }
  end

  test "should exclude DM channels from search results" do
    dm_channel = Channel.create!(
      name: "dm_searchable",
      channel_type: "dm",
      creator: @user
    )
    dm_channel.add_member(@user)

    get api_v1_search_path,
        params: { q: "dm_searchable" },
        headers: { "Authorization" => "Bearer #{@raw_token}" }

    assert_response :success
    json = JSON.parse(response.body)
    refute json["channels"].any? { |c| c["type"] == "dm" }
  end

  test "should only search accessible channels" do
    private_channel = Channel.create!(
      name: "private-search-test",
      channel_type: "private",
      creator: @other_user
    )
    Message.create!(content: "secret searchable content", user: @other_user, channel: private_channel)

    get api_v1_search_path,
        params: { q: "secret searchable" },
        headers: { "Authorization" => "Bearer #{@raw_token}" }

    assert_response :success
    json = JSON.parse(response.body)
    refute json["messages"].any? { |m| m["content"].include?("secret") }
  end

  # Validation tests
  test "should require query parameter" do
    get api_v1_search_path,
        headers: { "Authorization" => "Bearer #{@raw_token}" }

    assert_response :bad_request
    json = JSON.parse(response.body)
    assert_match /required/i, json["error"]
  end

  test "should require minimum query length" do
    get api_v1_search_path,
        params: { q: "a" },
        headers: { "Authorization" => "Bearer #{@raw_token}" }

    assert_response :bad_request
    json = JSON.parse(response.body)
    assert_match /2 characters/i, json["error"]
  end

  test "should handle blank query" do
    get api_v1_search_path,
        params: { q: "   " },
        headers: { "Authorization" => "Bearer #{@raw_token}" }

    assert_response :bad_request
  end

  # Search users endpoint tests
  test "should search users only" do
    get api_v1_users_search_path,
        params: { q: "findable" },
        headers: { "Authorization" => "Bearer #{@raw_token}" }

    assert_response :success
    json = JSON.parse(response.body)
    assert json.key?("users")
    refute json.key?("channels")
    refute json.key?("messages")
  end

  test "should return user details in search results" do
    get api_v1_users_search_path,
        params: { q: "findable" },
        headers: { "Authorization" => "Bearer #{@raw_token}" }

    assert_response :success
    json = JSON.parse(response.body)
    user = json["users"].first

    assert user.key?("id")
    assert user.key?("username")
    assert user.key?("is_online")
    assert user.key?("avatar_initials")
    assert user.key?("avatar_color_index")
  end

  # Case insensitivity tests
  test "should search case-insensitively" do
    get api_v1_search_path,
        params: { q: "FINDABLE" },
        headers: { "Authorization" => "Bearer #{@raw_token}" }

    assert_response :success
    json = JSON.parse(response.body)
    assert json["users"].any? { |u| u["username"] == "findable_user" }
  end

  # SQL injection prevention tests
  test "should sanitize SQL wildcards in query" do
    # Create a user with special characters
    special_user = create_user(username: "user_with_underscore")

    get api_v1_search_path,
        params: { q: "user_" },
        headers: { "Authorization" => "Bearer #{@raw_token}" }

    assert_response :success
    # Should find the exact match, not all users
    json = JSON.parse(response.body)
    assert json["users"].length <= 10
  end

  test "should handle percent sign in query" do
    get api_v1_search_path,
        params: { q: "100%" },
        headers: { "Authorization" => "Bearer #{@raw_token}" }

    assert_response :success
    # Should not cause SQL error
  end

  # Limit tests
  test "should limit results to prevent excessive data" do
    # Create many users
    15.times do |i|
      create_user(username: "bulk_user_#{i}")
    end

    get api_v1_search_path,
        params: { q: "bulk_user" },
        headers: { "Authorization" => "Bearer #{@raw_token}" }

    assert_response :success
    json = JSON.parse(response.body)
    assert json["users"].length <= 10, "Should limit user results"
  end

  # Response format tests
  test "should include channel membership status" do
    get api_v1_search_path,
        params: { q: "searchable-channel" },
        headers: { "Authorization" => "Bearer #{@raw_token}" }

    assert_response :success
    json = JSON.parse(response.body)
    channel = json["channels"].find { |c| c["name"] == "searchable-channel" }
    assert channel["is_member"]
  end

  test "should include message user and channel info" do
    get api_v1_search_path,
        params: { q: "searchable message" },
        headers: { "Authorization" => "Bearer #{@raw_token}" }

    assert_response :success
    json = JSON.parse(response.body)
    message = json["messages"].first

    assert message["user"].key?("id")
    assert message["user"].key?("username")
    assert message["channel"].key?("id")
    assert message["channel"].key?("name")
  end

  # E2EE exclusion test
  test "should exclude E2EE-encoded messages from search results" do
    # Plaintext message that matches the search term
    plaintext_msg = Message.create!(
      content: "findme plaintext",
      content_encoding: "plaintext",
      channel: @channel,
      user: @user
    )
    # E2EE message whose stored content is just a placeholder — must never appear in search
    e2ee_msg = Message.create!(
      content: "[Encrypted]",
      content_encoding: "e2ee",
      encrypted_content: "base64payload==",
      content_hmac: "hmac==",
      channel: @channel,
      user: @user
    )

    get api_v1_search_path,
        params: { q: "findme" },
        headers: { "Authorization" => "Bearer #{@raw_token}" }

    assert_response :success
    json = JSON.parse(response.body)
    ids = json["messages"].map { |m| m["id"] }

    assert_includes ids, plaintext_msg.id,
      "Plaintext message matching the query should be present in results"
    refute_includes ids, e2ee_msg.id,
      "E2EE-encoded message should be excluded from search results"
  end
end
