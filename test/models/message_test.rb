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

  test "e2ee message in private channel requires sender metadata and stores placeholder content" do
    owner = create_user(username: "owner_e2ee_private")
    recipient = create_user(username: "recipient_e2ee_private")
    channel = Channel.create!(name: "private-e2ee-model", channel_type: "private", created_by: owner)
    channel.add_member(owner)
    channel.add_member(recipient)

    invalid = channel.messages.build(
      user: owner,
      content: "plaintext",
      content_encoding: "e2ee",
      encrypted_content: "{\"v\":\"1\"}",
      content_hmac: "hmac-model"
    )
    refute invalid.valid?
    assert_includes invalid.errors[:sender_device_id], "can't be blank"
    assert_includes invalid.errors[:e2ee_version], "can't be blank"

    valid = channel.messages.build(
      user: owner,
      content: "plaintext-should-not-persist",
      content_encoding: "e2ee",
      encrypted_content: "{\"v\":\"1\",\"iv\":\"abc\",\"ciphertext\":\"def\"}",
      content_hmac: "hmac-model-ok",
      sender_device_id: "device-model-test",
      e2ee_version: "1"
    )

    assert valid.valid?
    valid.save!
    assert_equal E2eePolicy::PLACEHOLDER_CONTENT, valid.content
  end
end
