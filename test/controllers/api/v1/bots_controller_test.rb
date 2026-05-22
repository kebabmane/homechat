require "test_helper"

class Api::V1::BotsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @admin = create_user(username: "admin", role: "admin")
    @user = create_user(username: "regular")
    @admin_token = ApiToken.create!(name: "Admin Token", user: @admin, scopes: [ "admin:*" ])
    @user_token = ApiToken.create!(name: "User Token", user: @user, scopes: [ "user:messages" ])
    @bot = Bot.create!(name: "Test Bot", bot_type: "webhook")
  end

  # Authentication tests
  test "should require authentication for index" do
    get api_v1_bots_path
    assert_response :unauthorized
  end

  test "should require authentication for show" do
    get api_v1_bot_path(@bot)
    assert_response :unauthorized
  end

  test "should require authentication for create" do
    post api_v1_bots_path, params: { name: "New Bot" }
    assert_response :unauthorized
  end

  test "should require authentication for update" do
    patch api_v1_bot_path(@bot), params: { name: "Updated" }
    assert_response :unauthorized
  end

  test "should require authentication for destroy" do
    delete api_v1_bot_path(@bot)
    assert_response :unauthorized
  end

  # Authorization tests
  test "should forbid non-admin from index" do
    get api_v1_bots_path, headers: { "Authorization" => "Bearer #{@user_token.token}" }
    assert_response :forbidden
  end

  test "should forbid non-admin from show" do
    get api_v1_bot_path(@bot), headers: { "Authorization" => "Bearer #{@user_token.token}" }
    assert_response :forbidden
  end

  test "should forbid non-admin from create" do
    post api_v1_bots_path,
         params: { name: "New Bot", bot_type: "webhook" },
         headers: { "Authorization" => "Bearer #{@user_token.token}" }
    assert_response :forbidden
  end

  test "should forbid non-admin from update" do
    patch api_v1_bot_path(@bot),
          params: { name: "Updated" },
          headers: { "Authorization" => "Bearer #{@user_token.token}" }
    assert_response :forbidden
  end

  test "should forbid non-admin from destroy" do
    delete api_v1_bot_path(@bot), headers: { "Authorization" => "Bearer #{@user_token.token}" }
    assert_response :forbidden
    assert Bot.exists?(@bot.id)
  end

  test "should allow admin to list bots" do
    get api_v1_bots_path, headers: { "Authorization" => "Bearer #{@admin_token.token}" }
    assert_response :success
    json = JSON.parse(response.body)
    assert json["bots"].is_a?(Array)
    bot_names = json["bots"].map { |b| b["name"] }
    assert_includes bot_names, "Test Bot"
  end

  test "should allow admin to show bot" do
    get api_v1_bot_path(@bot), headers: { "Authorization" => "Bearer #{@admin_token.token}" }
    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "Test Bot", json["bot"]["name"]
  end

  test "should allow admin to create bot" do
    assert_difference("Bot.count", 1) do
      post api_v1_bots_path,
           params: { name: "New Bot", bot_type: "webhook" },
           headers: { "Authorization" => "Bearer #{@admin_token.token}" }
    end
    assert_response :success
  end

  test "should allow admin to update bot" do
    patch api_v1_bot_path(@bot),
          params: { name: "Updated Bot" },
          headers: { "Authorization" => "Bearer #{@admin_token.token}" }
    assert_response :success
    @bot.reload
    assert_equal "Updated Bot", @bot.name
  end

  test "should allow admin to delete bot" do
    assert_difference("Bot.count", -1) do
      delete api_v1_bot_path(@bot), headers: { "Authorization" => "Bearer #{@admin_token.token}" }
    end
    assert_response :success
  end

  test "should allow admin to activate bot" do
    @bot.update!(active: false)
    post activate_api_v1_bot_path(@bot), headers: { "Authorization" => "Bearer #{@admin_token.token}" }
    assert_response :success
    @bot.reload
    assert @bot.active?
  end

  test "should allow admin to deactivate bot" do
    @bot.update!(active: true)
    post deactivate_api_v1_bot_path(@bot), headers: { "Authorization" => "Bearer #{@admin_token.token}" }
    assert_response :success
    @bot.reload
    assert_not @bot.active?
  end

  test "should return existing bot on idempotent create" do
    post api_v1_bots_path,
         params: { name: "Test Bot", bot_type: "webhook" },
         headers: { "Authorization" => "Bearer #{@admin_token.token}" }
    assert_response :success
    assert_equal 1, Bot.where(name: "Test Bot").count
  end

  test "should handle nonexistent bot" do
    get api_v1_bot_path(99999), headers: { "Authorization" => "Bearer #{@admin_token.token}" }
    assert_response :not_found
  end
end
