require "test_helper"

class MessageTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    clear_enqueued_jobs
    clear_performed_jobs
  end

  teardown do
    clear_enqueued_jobs
    clear_performed_jobs
  end

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
    assert_not invalid.valid?
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

  test "enqueues link preview fetch jobs for unique URLs" do
    owner = create_user(username: "owner_preview_jobs")
    channel = Channel.create!(name: "link-preview-room-#{SecureRandom.hex(4)}", channel_type: "public", created_by: owner)
    channel.add_member(owner)

    assert_enqueued_jobs 2, only: LinkPreviewFetchJob do
      channel.messages.create!(
        user: owner,
        content: "look https://example.com and https://example.org and https://example.com again",
        message_type: "chat"
      )
    end
  end

  test "rejects oversized file attachments" do
    user = create_user(username: "file_user")
    channel = Channel.create!(name: "file-channel", created_by: user)
    message = Message.new(content: "test", user: user, channel: channel)

    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("x" * (Message::MAX_FILE_SIZE + 1)),
      filename: "large.txt",
      content_type: "text/plain"
    )
    message.files.attach(blob)

    assert_not message.valid?
    assert_includes message.errors[:files], "large.txt must be less than 10MB"
  end

  test "rejects file attachments on e2ee messages" do
    user = create_user(username: "e2ee_file_user")
    channel = Channel.create!(name: "private-e2ee-file-channel", channel_type: "private", created_by: user)
    channel.add_member(user)
    message = Message.new(
      content: "ignored",
      user: user,
      channel: channel,
      content_encoding: "e2ee",
      encrypted_content: "{\"v\":\"1\",\"iv\":\"abc\",\"ciphertext\":\"def\"}",
      content_hmac: "hmac-files",
      sender_device_id: "device-e2ee-files",
      e2ee_version: "1"
    )

    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("encrypted channel plaintext attachment"),
      filename: "secret.txt",
      content_type: "text/plain"
    )
    message.files.attach(blob)

    assert_not message.valid?
    assert_includes message.errors[:files], "are not supported on end-to-end encrypted messages"
  end

  test "rejects disallowed file content types" do
    user = create_user(username: "file_user2")
    channel = Channel.create!(name: "file-channel2", created_by: user)
    message = Message.new(content: "test", user: user, channel: channel)

    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("#!/bin/bash\necho evil"),
      filename: "evil.sh",
      content_type: "application/x-sh"
    )
    message.files.attach(blob)

    assert_not message.valid?
    assert_includes message.errors[:files], "evil.sh has unsupported type (application/x-sh). Allowed: images, videos, audio, PDF, plain text"
  end

  test "rejects too many file attachments" do
    user = create_user(username: "file_user3")
    channel = Channel.create!(name: "file-channel3", created_by: user)
    message = Message.new(content: "test", user: user, channel: channel)

    (Message::MAX_FILES_PER_MESSAGE + 1).times do |i|
      blob = ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new("file #{i}"),
        filename: "file#{i}.txt",
        content_type: "text/plain"
      )
      message.files.attach(blob)
    end

    assert_not message.valid?
    assert_includes message.errors[:files], "cannot exceed #{Message::MAX_FILES_PER_MESSAGE} per message"
  end

  test "accepts valid image file attachments" do
    user = create_user(username: "file_user4")
    channel = Channel.create!(name: "file-channel4", created_by: user)
    message = Message.new(content: "test", user: user, channel: channel)

    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("fake image data"),
      filename: "photo.png",
      content_type: "image/png"
    )
    message.files.attach(blob)

    assert message.valid?
  end
end
