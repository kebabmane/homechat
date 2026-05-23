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

    assert_equal [], page.evaluate_script(<<~JS)
      Object.keys(localStorage).filter((key) =>
        key === "homechat_e2ee_device_bundle_v2" ||
        key.startsWith("homechat_e2ee_channel_key_") ||
        key.startsWith("homechat_e2ee_channel_key_v2_")
      )
    JS

    stored_key_state = page.evaluate_async_script(<<~JS)
      const done = arguments[0];
      const request = indexedDB.open("homechat_e2ee_key_store_v2", 1);
      request.onerror = () => done({ error: "open failed" });
      request.onsuccess = () => {
        const db = request.result;
        const getRequest = db
          .transaction("keys", "readonly")
          .objectStore("keys")
          .get("homechat_e2ee_device_bundle_v2");
        getRequest.onerror = () => done({ error: "read failed" });
        getRequest.onsuccess = () => {
          const bundle = getRequest.result;
          done({
            encryptionPrivateExtractable: bundle?.encryptionPrivateCryptoKey?.extractable,
            signingPrivateExtractable: bundle?.signingPrivateCryptoKey?.extractable
          });
        };
      };
    JS

    assert_nil stored_key_state["error"]
    assert_equal false, stored_key_state["encryptionPrivateExtractable"]
    assert_equal false, stored_key_state["signingPrivateExtractable"]
  end
end
