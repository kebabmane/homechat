require "test_helper"

class ChatChannelRateLimitedTest < ActionCable::Channel::TestCase
  tests ChatChannel

  def setup
    @user = create_user(username: "rate_limit_chat_user")
  end

  test "allows up to 10 messages per second" do
    channel = Channel.create!(name: "rate-limit-chat", channel_type: "public", creator: @user)
    channel.add_member(@user)
    stub_connection current_user: @user, current_api_token_id: nil
    subscribe channel_id: channel.id

    10.times do |i|
      assert_changes -> { broadcasts("chat_channel_#{channel.id}").size } do
        perform :speak, message: "msg #{i}"
      end
    end

    # 11th message within the same window should be silently dropped
    assert_no_broadcasts("chat_channel_#{channel.id}") do
      perform :speak, message: "dropped"
    end
  end

  test "rate limit resets after window" do
    channel = Channel.create!(name: "rate-limit-chat-reset", channel_type: "public", creator: @user)
    channel.add_member(@user)
    stub_connection current_user: @user, current_api_token_id: nil
    subscribe channel_id: channel.id

    10.times { perform :speak, message: "msg" }

    travel 2.seconds do
      assert_changes -> { broadcasts("chat_channel_#{channel.id}").size } do
        perform :speak, message: "after reset"
      end
    end
  end

  test "receipt is not rate limited" do
    channel = Channel.create!(name: "rate-limit-receipt", channel_type: "public", creator: @user)
    channel.add_member(@user)
    message = channel.messages.create!(content: "hello", user: @user)
    stub_connection current_user: @user, current_api_token_id: nil
    subscribe channel_id: channel.id

    # Exhaust speak limit
    10.times { perform :speak, message: "msg" }

    # receipt should still work even though speak is throttled
    assert_broadcasts("chat_channel_#{channel.id}", 1) do
      perform :receipt, message_id: message.id, status: "read"
    end
  end
end

class TypingChannelRateLimitedTest < ActionCable::Channel::TestCase
  tests TypingChannel

  def setup
    @user = create_user(username: "rate_limit_typing_user")
  end

  test "allows 1 typing event per second" do
    channel = Channel.create!(name: "rate-limit-typing", channel_type: "public", creator: @user)
    channel.add_member(@user)
    stub_connection current_user: @user
    subscribe id: channel.id

    assert_broadcasts("typing:#{channel.id}", 1) do
      perform :typing, {}
    end

    # Second event within 1 second should be dropped
    assert_no_broadcasts("typing:#{channel.id}") do
      perform :typing, {}
    end
  end

  test "stop_typing is also rate limited" do
    channel = Channel.create!(name: "rate-limit-stop", channel_type: "public", creator: @user)
    channel.add_member(@user)
    stub_connection current_user: @user
    subscribe id: channel.id

    assert_broadcasts("typing:#{channel.id}", 1) do
      perform :stop_typing, {}
    end

    assert_no_broadcasts("typing:#{channel.id}") do
      perform :stop_typing, {}
    end
  end

  test "rate limit resets after window" do
    channel = Channel.create!(name: "rate-limit-typing-reset", channel_type: "public", creator: @user)
    channel.add_member(@user)
    stub_connection current_user: @user
    subscribe id: channel.id

    perform :typing, {}

    travel 2.seconds do
      assert_broadcasts("typing:#{channel.id}", 1) do
        perform :typing, {}
      end
    end
  end
end

class PresenceChannelRateLimitedTest < ActionCable::Channel::TestCase
  tests PresenceChannel

  def setup
    @user = create_user(username: "rate_limit_presence_user")
  end

  test "allows 1 heartbeat per second" do
    stub_connection current_user: @user
    subscribe

    # Advance past the presence stale window so heartbeat actually updates the DB
    travel 31.seconds do
      old_last_seen = @user.last_seen_at

      assert_nothing_raised do
        perform :heartbeat
      end
      @user.reload
      assert_not_equal old_last_seen, @user.last_seen_at

      # Second heartbeat within 1 second should be silently dropped
      last_seen_after_first = @user.last_seen_at
      assert_nothing_raised do
        perform :heartbeat
      end
      @user.reload
      assert_equal last_seen_after_first, @user.last_seen_at
    end
  end

  test "set_status is rate limited" do
    stub_connection current_user: @user
    subscribe

    assert_nothing_raised do
      perform :set_status, status: "away"
    end

    # Second within 1 second should be silently dropped
    assert_nothing_raised do
      perform :set_status, status: "busy"
    end
  end

  test "rate limit resets after window" do
    stub_connection current_user: @user
    subscribe

    perform :heartbeat

    travel 2.seconds do
      assert_nothing_raised do
        perform :heartbeat
      end
    end
  end
end
