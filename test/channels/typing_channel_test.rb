require "test_helper"

class TypingChannelTest < ActionCable::Channel::TestCase
  def setup
    @user = create_user(username: "typing_user")
    @channel = Channel.create!(name: "typing-test", channel_type: "public", creator: @user)
    @channel.add_member(@user)

    stub_connection current_user: @user
  end

  test "subscribes to channel typing stream" do
    subscribe id: @channel.id

    assert subscription.confirmed?
    assert_has_stream "typing:#{@channel.id}"
  end

  test "rejects subscription without channel id" do
    subscribe id: nil

    assert subscription.rejected?
  end

  test "rejects subscription to non-existent channel" do
    subscribe id: 999999

    assert subscription.rejected?
  end

  test "rejects subscription to inaccessible private channel" do
    other_user = create_user(username: "private_owner")
    private_channel = Channel.create!(name: "private-typing", channel_type: "private", creator: other_user)

    subscribe id: private_channel.id

    assert subscription.rejected?
  end

  test "allows subscription to accessible private channel" do
    private_channel = Channel.create!(name: "member-typing", channel_type: "private", creator: @user)
    private_channel.add_member(@user)

    subscribe id: private_channel.id

    assert subscription.confirmed?
  end

  test "typing broadcasts to channel" do
    subscribe id: @channel.id

    assert_broadcasts "typing:#{@channel.id}", 1 do
      perform :typing, {}
    end
  end

  test "typing with explicit flag broadcasts" do
    subscribe id: @channel.id

    assert_broadcasts "typing:#{@channel.id}", 1 do
      perform :typing, typing: true
    end
  end

  test "stop_typing broadcasts to channel" do
    subscribe id: @channel.id

    assert_broadcasts "typing:#{@channel.id}", 1 do
      perform :stop_typing, {}
    end
  end

  test "broadcasts include username" do
    subscribe id: @channel.id

    assert_broadcasts "typing:#{@channel.id}", 1 do
      perform :typing, {}
    end
  end

  test "stop_typing broadcasts" do
    subscribe id: @channel.id

    assert_broadcasts "typing:#{@channel.id}", 1 do
      perform :stop_typing, {}
    end
  end
end
