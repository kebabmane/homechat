require "test_helper"

class BotTest < ActiveSupport::TestCase
  test "should require name" do
    bot = Bot.new
    assert_not bot.valid?
    assert_includes bot.errors[:name], "can't be blank"
  end

  test "should require unique name" do
    Bot.create!(name: "Test Bot")
    duplicate_bot = Bot.new(name: "Test Bot")
    assert_not duplicate_bot.valid?
    assert_includes duplicate_bot.errors[:name], "has already been taken"
  end

  test "should set default bot_type" do
    bot = Bot.new(name: "Test Bot", bot_type: nil)
    bot.valid? # Trigger validation callbacks
    # The set_defaults callback should set bot_type to 'webhook'
    assert_equal "webhook", bot.bot_type
  end

  test "should validate bot_type inclusion" do
    bot = Bot.new(name: "Test Bot", bot_type: "invalid")
    assert_not bot.valid?
    assert_includes bot.errors[:bot_type], "is not included in the list"
  end

  test "should accept valid bot_types" do
    webhook_bot = Bot.create!(name: "Webhook Bot", bot_type: "webhook")
    api_bot = Bot.create!(name: "API Bot", bot_type: "api")

    assert webhook_bot.valid?
    assert api_bot.valid?
  end

  test "should be active by default" do
    bot = Bot.create!(name: "Test Bot")
    assert bot.active?
  end

  test "should default to webhook bot_type" do
    bot = Bot.create!(name: "Test Bot")
    assert_equal "webhook", bot.bot_type
    assert bot.webhook?
  end

  test "should generate webhook_id for webhook bots" do
    bot = Bot.new(name: "Test Bot", bot_type: "webhook", webhook_id: nil)
    bot.valid? # Trigger validation callbacks
    # The set_defaults callback should generate webhook_id
    assert_not_nil bot.webhook_id
  end

  test "should not require webhook_id for api bots" do
    bot = Bot.create!(name: "API Bot", bot_type: "api")
    assert bot.valid?
    assert_nil bot.webhook_id
  end

  test "should have unique webhook_id" do
    bot1 = Bot.create!(name: "Bot 1", bot_type: "webhook")
    bot2 = Bot.new(name: "Bot 2", bot_type: "webhook", webhook_id: bot1.webhook_id)
    assert_not bot2.valid?
    assert_includes bot2.errors[:webhook_id], "has already been taken"
  end

  test "should auto-generate UUID webhook_id for new webhook bots" do
    bot = Bot.create!(name: "Webhook Bot", bot_type: "webhook")
    assert_not_nil bot.webhook_id
    assert bot.webhook_id.match?(/\A[0-9a-f-]{36}\z/i) # UUID format
  end

  test "should generate webhook_url" do
    bot = Bot.create!(name: "Webhook Bot", bot_type: "webhook")
    base_url = "https://example.com"
    expected_url = "#{base_url}/api/v1/webhooks/#{bot.webhook_id}"
    assert_equal expected_url, bot.webhook_url(base_url)
  end

  test "should return nil webhook_url for api bots" do
    bot = Bot.create!(name: "API Bot", bot_type: "api")
    assert_nil bot.webhook_url("https://example.com")
  end

  test "should deactivate and activate bots" do
    bot = Bot.create!(name: "Test Bot")
    assert bot.active?

    bot.deactivate!
    assert_not bot.active?

    bot.activate!
    assert bot.active?
  end

  test "should scope active bots" do
    active_bot = Bot.create!(name: "Active Bot", active: true)
    inactive_bot = Bot.create!(name: "Inactive Bot", active: false)

    assert_includes Bot.active, active_bot
    assert_not_includes Bot.active, inactive_bot
  end

  test "should scope webhook bots" do
    webhook_bot = Bot.create!(name: "Webhook Bot", bot_type: "webhook")
    api_bot = Bot.create!(name: "API Bot", bot_type: "api")

    assert_includes Bot.webhooks, webhook_bot
    assert_not_includes Bot.webhooks, api_bot
  end

  test "should scope api bots" do
    webhook_bot = Bot.create!(name: "Webhook Bot", bot_type: "webhook")
    api_bot = Bot.create!(name: "API Bot", bot_type: "api")

    assert_includes Bot.api_bots, api_bot
    assert_not_includes Bot.api_bots, webhook_bot
  end

  test "should identify bot type" do
    webhook_bot = Bot.create!(name: "Webhook Bot", bot_type: "webhook")
    api_bot = Bot.create!(name: "API Bot", bot_type: "api")

    assert webhook_bot.webhook?
    assert_not webhook_bot.api_bot?

    assert api_bot.api_bot?
    assert_not api_bot.webhook?
  end

  test "should generate webhook secret for webhook bots" do
    bot = Bot.create!(name: "Webhook Bot", bot_type: "webhook")
    assert_not_nil bot.webhook_secret
    assert_equal 64, bot.webhook_secret.length # 32 bytes = 64 hex chars
  end

  test "should not require webhook secret for api bots" do
    bot = Bot.create!(name: "API Bot", bot_type: "api")
    assert bot.valid?
    assert_nil bot.webhook_secret
  end

  test "should regenerate webhook secret" do
    bot = Bot.create!(name: "Webhook Bot", bot_type: "webhook")
    original_secret = bot.webhook_secret

    bot.regenerate_webhook_secret!
    bot.reload

    assert_not_equal original_secret, bot.webhook_secret
    assert_equal 64, bot.webhook_secret.length
  end

  test "should not regenerate secret for api bots" do
    bot = Bot.create!(name: "API Bot", bot_type: "api")
    bot.regenerate_webhook_secret!

    assert_nil bot.webhook_secret
  end

  test "should verify webhook signature with valid signature" do
    bot = Bot.create!(name: "Webhook Bot", bot_type: "webhook")
    payload = '{"message": "test"}'
    signature = OpenSSL::HMAC.hexdigest('SHA256', bot.webhook_secret, payload)
    signature_header = "sha256=#{signature}"

    assert bot.verify_webhook_signature(payload, signature_header)
  end

  test "should reject webhook signature with invalid signature" do
    bot = Bot.create!(name: "Webhook Bot", bot_type: "webhook")
    payload = '{"message": "test"}'
    invalid_signature = "sha256=invalid_signature_here"

    assert_not bot.verify_webhook_signature(payload, invalid_signature)
  end

  test "should reject webhook signature with wrong payload" do
    bot = Bot.create!(name: "Webhook Bot", bot_type: "webhook")
    payload = '{"message": "test"}'
    wrong_payload = '{"message": "different"}'
    signature = OpenSSL::HMAC.hexdigest('SHA256', bot.webhook_secret, wrong_payload)
    signature_header = "sha256=#{signature}"

    assert_not bot.verify_webhook_signature(payload, signature_header)
  end

  test "should reject webhook signature without sha256 prefix" do
    bot = Bot.create!(name: "Webhook Bot", bot_type: "webhook")
    payload = '{"message": "test"}'
    signature = OpenSSL::HMAC.hexdigest('SHA256', bot.webhook_secret, payload)

    assert_not bot.verify_webhook_signature(payload, signature) # No "sha256=" prefix
  end

  test "should reject webhook signature with empty header" do
    bot = Bot.create!(name: "Webhook Bot", bot_type: "webhook")
    payload = '{"message": "test"}'

    assert_not bot.verify_webhook_signature(payload, "")
    assert_not bot.verify_webhook_signature(payload, nil)
  end

  test "should reject webhook signature for api bots" do
    bot = Bot.create!(name: "API Bot", bot_type: "api")
    payload = '{"message": "test"}'
    signature_header = "sha256=some_signature"

    assert_not bot.verify_webhook_signature(payload, signature_header)
  end

  test "should reject webhook signature when bot has no secret" do
    bot = Bot.create!(name: "Webhook Bot", bot_type: "webhook")
    bot.update_column(:webhook_secret, nil) # Remove secret

    payload = '{"message": "test"}'
    signature_header = "sha256=some_signature"

    assert_not bot.verify_webhook_signature(payload, signature_header)
  end
end