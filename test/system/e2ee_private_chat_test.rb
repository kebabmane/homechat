require "application_system_test_case"

class E2eePrivateChatTest < JsSystemTestCase
  test "dm message is encrypted at rest and decrypted in UI" do
    alice = User.create!(username: "alice_e2ee", password: "password123", password_confirmation: "password123")
    bob = User.create!(username: "bob_e2ee", password: "password123", password_confirmation: "password123")

    dm_channel = Channel.create!(name: "dm-alice-bob-e2ee", channel_type: "dm", created_by: alice)
    dm_channel.add_member(alice)
    dm_channel.add_member(bob)

    sign_in(username: alice.username, password: "password123")

    visit channel_path(dm_channel)

    input = find_field("message_content")
    input.set("super secret dm text")
    input.send_keys(:enter)

    assert_text "super secret dm text"

    message = Message.order(:created_at).last
    assert_equal dm_channel.id, message.channel_id
    assert_equal "e2ee", message.content_encoding
    assert_equal E2eePolicy::PLACEHOLDER_CONTENT, message.content
    assert message.encrypted_content.present?
    assert message.content_hmac.present?
  end
end
