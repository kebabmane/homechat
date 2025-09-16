require "test_helper"

class Api::V1::WebhooksControllerTest < ActionDispatch::IntegrationTest
  def setup
    @bot = Bot.create!(name: "Test Webhook Bot", bot_type: "webhook")
    @webhook_url = "/api/v1/webhooks/#{@bot.webhook_id}"
    @valid_payload = { message: "Hello from webhook" }.to_json
    @valid_signature = generate_signature(@valid_payload, @bot.webhook_secret)
  end

  test "should accept webhook with valid signature" do
    post_raw_json(@webhook_url, @valid_payload, @valid_signature)

    assert_response :success
    response_data = JSON.parse(response.body)
    assert_equal 'ok', response_data['status']
    assert_equal 'Webhook processed successfully', response_data['message']
  end

  test "should accept webhook with alternative signature header" do
    post_raw_json(@webhook_url, @valid_payload, @valid_signature, 'X-Signature-256')

    assert_response :success
  end

  test "should reject webhook with invalid signature" do
    invalid_signature = "sha256=invalid_signature_here"
    post_raw_json(@webhook_url, @valid_payload, invalid_signature)

    assert_response :unauthorized
    response_data = JSON.parse(response.body)
    assert_equal 'Invalid webhook signature', response_data['error']
  end

  test "should reject webhook without signature header" do
    post_raw_json(@webhook_url, @valid_payload, nil)

    assert_response :unauthorized
    response_data = JSON.parse(response.body)
    assert_equal 'Invalid webhook signature', response_data['error']
  end

  test "should reject webhook with wrong payload but valid signature format" do
    wrong_payload = { message: "Different message" }.to_json
    signature_for_wrong_payload = generate_signature(wrong_payload, @bot.webhook_secret)

    # Send original payload but with signature for different payload
    post_raw_json(@webhook_url, @valid_payload, signature_for_wrong_payload)

    assert_response :unauthorized
    response_data = JSON.parse(response.body)
    assert_equal 'Invalid webhook signature', response_data['error']
  end

  test "should reject webhook with invalid webhook ID" do
    invalid_webhook_url = "/api/v1/webhooks/invalid-webhook-id"
    post_raw_json(invalid_webhook_url, @valid_payload, @valid_signature)

    assert_response :unauthorized
    response_data = JSON.parse(response.body)
    assert_equal 'Invalid webhook ID or bot inactive', response_data['error']
  end

  test "should reject webhook for inactive bot" do
    @bot.deactivate!
    post_raw_json(@webhook_url, @valid_payload, @valid_signature)

    assert_response :unauthorized
    response_data = JSON.parse(response.body)
    assert_equal 'Invalid webhook ID or bot inactive', response_data['error']
  end

  test "should reject webhook without webhook ID" do
    post_raw_json("/api/v1/webhooks/", @valid_payload, @valid_signature)

    assert_response :not_found # Rails will return 404 for missing route parameter
  end

  test "should handle send_message action with valid signature" do
    payload = {
      action: 'send_message',
      message: 'Hello from webhook test',
      room_id: 'test-room'
    }.to_json

    signature = generate_signature(payload, @bot.webhook_secret)
    post_raw_json(@webhook_url, payload, signature)

    assert_response :success

    # Verify message was created
    channel = Channel.find_by(name: 'test-room')
    assert_not_nil channel
    assert channel.messages.where("content LIKE ?", "%Hello from webhook test%").exists?
  end

  test "should handle status_update action with valid signature" do
    payload = {
      action: 'status_update',
      status: 'Bot is running normally'
    }.to_json

    signature = generate_signature(payload, @bot.webhook_secret)
    post_raw_json(@webhook_url, payload, signature)

    assert_response :success

    # Verify status message was created in bot-status channel
    status_channel = Channel.find_by(name: 'bot-status')
    if status_channel.nil?
      # Debug: check what channels were created
      puts "Created channels: #{Channel.pluck(:name)}"
      puts "All messages: #{Message.last(5).map { |m| [m.content, m.channel.name] }}"
    end
    assert_not_nil status_channel
    assert status_channel.messages.where("content LIKE ?", "%Bot Status Update%").exists?
  end

  test "should handle command action with valid signature" do
    payload = {
      action: 'command',
      command: 'ping'
    }.to_json

    signature = generate_signature(payload, @bot.webhook_secret)
    post_raw_json(@webhook_url, payload, signature)

    assert_response :success

    # Verify ping response was created
    channel = Channel.find_by(name: 'home-assistant')
    assert_not_nil channel
    assert channel.messages.where(content: 'pong').exists?
  end

  # Note: Logging tests would require mock setup, skipping for now

  private

  def post_raw_json(url, json_payload, signature, header_name = 'X-Hub-Signature-256')
    headers = { 'Content-Type' => 'application/json' }
    headers[header_name] = signature if signature

    post url, params: json_payload, headers: headers
  end

  def generate_signature(payload, secret)
    signature = OpenSSL::HMAC.hexdigest('SHA256', secret, payload)
    "sha256=#{signature}"
  end
end