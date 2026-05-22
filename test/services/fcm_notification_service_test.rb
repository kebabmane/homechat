require "test_helper"

class FcmNotificationServiceTest < ActiveSupport::TestCase
  def setup
    @sender = create_user(username: "sender")
    @recipient = create_user(username: "recipient")
    @recipient.update!(fcm_token: "test-fcm-token-recipient")

    @channel = Channel.create!(
      name: "general",
      channel_type: "public",
      creator: @sender
    )
    @channel.add_member(@sender)
    @channel.add_member(@recipient)

    @message = Message.create!(
      content: "Hello this is secret content",
      channel: @channel,
      user: @sender
    )

    # Stub Google Auth so tests don't hit the network
    FcmNotificationService.instance_variable_set(:@access_token, "stub-access-token")

    # Stub the project_id and credentials check so fcm_configured? returns true
    FcmNotificationService.instance_variable_set(:@fcm_config, {
      "project_id" => "test-project-123",
      "service_account_json" => { "type" => "service_account" }.to_json
    }.with_indifferent_access)
  end

  def teardown
    # Clear memoized class-level state between tests
    FcmNotificationService.instance_variable_set(:@access_token, nil)
    FcmNotificationService.instance_variable_set(:@fcm_config, nil)
    FcmNotificationService.instance_variable_set(:@project_id, nil)
    FcmNotificationService.instance_variable_set(:@service_account_json, nil)
  end

  # ─────────────────────────────────────────────────────────────────────────
  # send_message_notification
  # ─────────────────────────────────────────────────────────────────────────

  test "send_message_notification data payload omits content key" do
    captured_body = nil

    http_stub = Object.new
    http_stub.define_singleton_method(:use_ssl=) { |_| }
    http_stub.define_singleton_method(:verify_mode=) { |_| }
    http_stub.define_singleton_method(:open_timeout=) { |_| }
    http_stub.define_singleton_method(:read_timeout=) { |_| }
    http_stub.define_singleton_method(:request) do |req|
      captured_body = JSON.parse(req.body)
      stub_response = Object.new
      stub_response.define_singleton_method(:code) { "200" }
      stub_response
    end

    Net::HTTP.stub(:new, http_stub) do
      FcmNotificationService.send_message_notification(@message, exclude_user: @sender)
    end

    assert_not_nil captured_body, "Expected an HTTP request to be made"
    data_payload = captured_body.dig("message", "data") || {}
    assert_not data_payload.key?("content"),
      "FCM data payload must not include 'content' key (E2EE privacy)"
    assert_equal @channel.id.to_s, data_payload["channel_id"]
    assert_equal @message.id.to_s, data_payload["message_id"]
  end

  test "send_message_notification payload does not expose sender or channel names" do
    captured_body = nil

    http_stub = build_http_stub { |body| captured_body = body }

    Net::HTTP.stub(:new, http_stub) do
      FcmNotificationService.send_message_notification(@message, exclude_user: @sender)
    end

    assert_not_nil captured_body
    notification_payload = captured_body.dig("message", "notification")
    data_payload = captured_body.dig("message", "data") || {}
    apns_alert = captured_body.dig("message", "apns", "payload", "aps", "alert") || {}

    assert_nil notification_payload,
      "Android FCM should remain data-only so server-rendered notification text is not exposed"
    assert_equal "HomeChat", data_payload["title"]
    assert_equal "New message", data_payload["body"]
    assert_equal "HomeChat", apns_alert["title"]
    assert_equal "New message", apns_alert["body"]
    assert_not captured_body.to_json.include?(@message.content),
      "Notification body must not contain actual message content"
    assert_not captured_body.to_json.include?(@channel.name),
      "FCM payload must not expose channel names"
    assert_not captured_body.to_json.include?(@sender.username),
      "FCM payload must not expose sender names"
    assert_equal "generic", data_payload["notification_privacy"]
    assert_equal "message", data_payload["type"]
    assert_equal @channel.id.to_s, data_payload["channel_id"]
    assert_equal @message.id.to_s, data_payload["message_id"]
  end

  # ─────────────────────────────────────────────────────────────────────────
  # send_direct_message_notification
  # ─────────────────────────────────────────────────────────────────────────

  test "send_direct_message_notification data payload omits content key" do
    dm_channel = Channel.create!(name: "dm_channel", channel_type: "dm", creator: @sender)
    dm_channel.add_member(@sender)
    dm_channel.add_member(@recipient)
    dm_message = Message.create!(content: "private DM content", channel: dm_channel, user: @sender)

    captured_body = nil
    http_stub = build_http_stub { |body| captured_body = body }

    Net::HTTP.stub(:new, http_stub) do
      FcmNotificationService.send_direct_message_notification(dm_message, @recipient)
    end

    assert_not_nil captured_body
    data_payload = captured_body.dig("message", "data") || {}
    assert_not data_payload.key?("content"),
      "Direct message FCM payload must not include 'content' key"
    assert_equal dm_channel.id.to_s, data_payload["channel_id"]
    assert_equal dm_message.id.to_s, data_payload["message_id"]
  end

  test "send_direct_message_notification body is generic string" do
    dm_channel = Channel.create!(name: "dm_channel2", channel_type: "dm", creator: @sender)
    dm_channel.add_member(@sender)
    dm_channel.add_member(@recipient)
    dm_message = Message.create!(content: "very private content", channel: dm_channel, user: @sender)

    captured_body = nil
    http_stub = build_http_stub { |body| captured_body = body }

    Net::HTTP.stub(:new, http_stub) do
      FcmNotificationService.send_direct_message_notification(dm_message, @recipient)
    end

    assert_not_nil captured_body
    notification_payload = captured_body.dig("message", "notification")
    data_payload = captured_body.dig("message", "data") || {}
    apns_alert = captured_body.dig("message", "apns", "payload", "aps", "alert") || {}

    assert_nil notification_payload,
      "Android FCM should remain data-only so server-rendered notification text is not exposed"
    assert_equal "HomeChat", data_payload["title"]
    assert_equal "New direct message", data_payload["body"]
    assert_equal "HomeChat", apns_alert["title"]
    assert_equal "New direct message", apns_alert["body"]
    assert_not captured_body.to_json.include?(dm_message.content),
      "DM notification body must not contain actual message content"
    assert_not captured_body.to_json.include?(@sender.username),
      "DM notification payload must not expose sender names"
    assert_equal "generic", data_payload["notification_privacy"]
    assert_equal "direct_message", data_payload["type"]
    assert_equal dm_channel.id.to_s, data_payload["channel_id"]
    assert_equal dm_message.id.to_s, data_payload["message_id"]
  end

  # ─────────────────────────────────────────────────────────────────────────
  # send_mention_notification
  # ─────────────────────────────────────────────────────────────────────────

  test "send_mention_notification data payload omits content key" do
    captured_body = nil
    http_stub = build_http_stub { |body| captured_body = body }

    Net::HTTP.stub(:new, http_stub) do
      FcmNotificationService.send_mention_notification(@message, @recipient)
    end

    assert_not_nil captured_body
    data_payload = captured_body.dig("message", "data") || {}
    assert_not data_payload.key?("content"),
      "Mention FCM payload must not include 'content' key"
    assert_equal @channel.id.to_s, data_payload["channel_id"]
    assert_equal @message.id.to_s, data_payload["message_id"]
  end

  test "send_mention_notification body is generic and omits channel name" do
    captured_body = nil
    http_stub = build_http_stub { |body| captured_body = body }

    Net::HTTP.stub(:new, http_stub) do
      FcmNotificationService.send_mention_notification(@message, @recipient)
    end

    assert_not_nil captured_body
    notification_payload = captured_body.dig("message", "notification")
    data_payload = captured_body.dig("message", "data") || {}
    apns_alert = captured_body.dig("message", "apns", "payload", "aps", "alert") || {}

    assert_nil notification_payload,
      "Android FCM should remain data-only so server-rendered notification text is not exposed"
    assert_equal "HomeChat", data_payload["title"]
    assert_equal "New mention", data_payload["body"]
    assert_equal "HomeChat", apns_alert["title"]
    assert_equal "New mention", apns_alert["body"]
    assert_not captured_body.to_json.include?(@message.content),
      "Mention notification body must not contain actual message content"
    assert_not captured_body.to_json.include?(@channel.name),
      "Mention payload must not expose channel names"
    assert_not captured_body.to_json.include?(@sender.username),
      "Mention payload must not expose sender names"
    assert_equal "generic", data_payload["notification_privacy"]
    assert_equal "mention", data_payload["type"]
    assert_equal @channel.id.to_s, data_payload["channel_id"]
    assert_equal @message.id.to_s, data_payload["message_id"]
  end

  private

  # Builds a minimal Net::HTTP stub that captures the parsed request body
  # and returns a 200 OK response. Yields the parsed JSON body to the block.
  def build_http_stub(&capture_block)
    http_stub = Object.new
    http_stub.define_singleton_method(:use_ssl=) { |_| }
    http_stub.define_singleton_method(:verify_mode=) { |_| }
    http_stub.define_singleton_method(:open_timeout=) { |_| }
    http_stub.define_singleton_method(:read_timeout=) { |_| }
    http_stub.define_singleton_method(:request) do |req|
      capture_block.call(JSON.parse(req.body))
      stub_response = Object.new
      stub_response.define_singleton_method(:code) { "200" }
      stub_response
    end
    http_stub
  end
end
