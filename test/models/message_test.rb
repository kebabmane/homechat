require "test_helper"

class MessageTest < ActiveSupport::TestCase
  test "requires content and associations" do
    user = create_user(username: "bob")
    owner = create_user(username: "owner3")
    ch = Channel.create!(name: "roomx", created_by: owner)
    msg = Message.new(content: "hello", user: user, channel: ch)
    assert msg.valid?
    msg.save!
    assert_equal "hello", msg.content
  end

  test "mention invites user to public channel" do
    owner = create_user(username: "owner_public")
    channel = Channel.create!(name: "public-room", channel_type: "public", created_by: owner)
    channel.add_member(owner)
    invitee = create_user(username: "charlie")

    assert_not channel.members.exists?(id: invitee.id)

    channel.messages.create!(user: owner, content: "Hello there @charlie", message_type: "chat")

    assert channel.members.exists?(id: invitee.id), "invitee should be added to the channel"
  end

  test "mention invites user to private channel" do
    owner = create_user(username: "owner_private")
    channel = Channel.create!(name: "private-room", channel_type: "private", created_by: owner)
    channel.add_member(owner)
    invitee = create_user(username: "dana")

    assert_not channel.members.exists?(id: invitee.id)

    channel.messages.create!(user: owner, content: "Secret chat with @dana", message_type: "chat")

    assert channel.members.exists?(id: invitee.id), "invitee should be added to the private channel"
  end
end
