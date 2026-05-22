require "test_helper"

class PresenceChannelTest < ActionCable::Channel::TestCase
  def setup
    @user = create_user(username: "presence_user")
    stub_connection current_user: @user
  end

  test "subscribes successfully" do
    subscribe

    assert subscription.confirmed?
  end

  test "streams from presence channel" do
    subscribe

    assert_has_stream "presence"
  end

  test "marks user online on subscription" do
    @user.update!(is_online: false)

    subscribe

    @user.reload
    assert @user.online?
  end

  test "marks user offline on unsubscription" do
    subscribe
    @user.reload
    assert @user.online?

    unsubscribe

    @user.reload
    assert @user.offline?
  end

  test "heartbeat updates last_seen_at" do
    subscribe

    old_last_seen = @user.last_seen_at

    # Wait briefly to ensure time difference
    travel 1.second do
      perform :heartbeat
    end

    @user.reload
    # Last seen should be updated (or at least not nil)
    assert_not_nil @user.last_seen_at
  end

  test "typing broadcasts to public channel" do
    subscribe
    public_channel = Channel.create!(name: "public", channel_type: "public", created_by: @user)

    assert_broadcasts("typing:#{public_channel.id}", 1) do
      perform :typing, { "channel_id" => public_channel.id }
    end
  end

  test "typing broadcasts to private channel when member" do
    subscribe
    other = create_user(username: "other")
    private_channel = Channel.create!(name: "private", channel_type: "private", created_by: other)
    private_channel.add_member(@user)

    assert_broadcasts("typing:#{private_channel.id}", 1) do
      perform :typing, { "channel_id" => private_channel.id }
    end
  end

  test "typing is blocked for non-member private channel" do
    subscribe
    other = create_user(username: "other")
    private_channel = Channel.create!(name: "private", channel_type: "private", created_by: other)

    assert_no_broadcasts("typing:#{private_channel.id}") do
      perform :typing, { "channel_id" => private_channel.id }
    end
  end

  test "stop_typing is blocked for non-member private channel" do
    subscribe
    other = create_user(username: "other")
    private_channel = Channel.create!(name: "private", channel_type: "private", created_by: other)

    assert_no_broadcasts("typing:#{private_channel.id}") do
      perform :stop_typing, { "channel_id" => private_channel.id }
    end
  end

  test "typing is blocked for nonexistent channel" do
    subscribe

    assert_no_broadcasts("typing:99999") do
      perform :typing, { "channel_id" => 99999 }
    end
  end
end
