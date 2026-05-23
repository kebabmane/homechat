# frozen_string_literal: true

require "base64"
require "ed25519"

class E2eeSignatureVerifier
  KEY_SHARE_V2_PREFIX = "homechat-key-share-v2"

  class << self
    def key_share_payload(channel:, key_epoch:, recipient_user_id:, recipient_device_id:, recipient_key_fingerprint:, encrypted_channel_key:, sender_device_id:, sender_key_fingerprint:, key_version:)
      [
        KEY_SHARE_V2_PREFIX,
        channel.id,
        key_epoch,
        recipient_user_id,
        recipient_device_id,
        recipient_key_fingerprint,
        encrypted_channel_key,
        sender_device_id,
        sender_key_fingerprint,
        key_version
      ].map(&:to_s).join(":")
    end

    def valid_key_share_signature?(payload:, signature:, signing_public_key:)
      return false if payload.blank? || signature.blank? || signing_public_key.blank?

      verify_ed25519(payload:, signature:, signing_public_key:)
    rescue ArgumentError, Ed25519::VerifyError
      false
    end

    private

    def verify_ed25519(payload:, signature:, signing_public_key:)
      public_key = Base64.strict_decode64(signing_public_key)
      return false unless public_key.bytesize == 32

      Ed25519::VerifyKey.new(public_key).verify(Base64.strict_decode64(signature), payload)
      true
    end
  end
end
