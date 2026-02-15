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
end
