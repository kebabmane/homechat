# frozen_string_literal: true

class E2eePolicy
  HEADER_VERSION = 'X-HomeChat-E2EE-Version'
  HEADER_DEVICE_ID = 'X-HomeChat-Device-Id'

  REQUIRED_VERSION = '1'
  REQUIRED_ENCODING = 'e2ee'
  ENFORCED_CHANNEL_TYPES = %w[private dm].freeze
  PLACEHOLDER_CONTENT = '[Encrypted message]'
  LEGACY_UPGRADE_ERROR_CODE = 'e2ee_upgrade_required'
  BOT_FORBIDDEN_CODE = 'e2ee_bot_forbidden'

  DEVICE_ID_FORMAT = /\A[a-zA-Z0-9._:-]{8,128}\z/

  class << self
    def required_for_channel?(channel)
      channel.present? && ENFORCED_CHANNEL_TYPES.include?(channel.channel_type)
    end

    def e2ee_version_from(request: nil, params: nil)
      request&.headers&.[](HEADER_VERSION).presence ||
        value_from_params(params, :e2ee_version)
    end

    def device_id_from(request: nil, params: nil)
      request&.headers&.[](HEADER_DEVICE_ID).presence ||
        value_from_params(params, :device_id) ||
        value_from_params(params, :sender_device_id)
    end

    def valid_device_id?(device_id)
      device_id.present? && device_id.match?(DEVICE_ID_FORMAT)
    end

    def valid_e2ee_headers?(request: nil, params: nil)
      e2ee_version_from(request:, params:) == REQUIRED_VERSION &&
        valid_device_id?(device_id_from(request:, params:))
    end

    def valid_e2ee_payload?(payload)
      payload_hash = payload.respond_to?(:to_h) ? payload.to_h.with_indifferent_access : {}.with_indifferent_access

      payload_hash[:content_encoding].to_s == REQUIRED_ENCODING &&
        payload_hash[:encrypted_content].present? &&
        payload_hash[:content_hmac].present?
    end

    def validate_enforced_write(channel:, payload:, request: nil, allow_files: true)
      return nil unless required_for_channel?(channel)

      unless valid_e2ee_headers?(request:, params: payload)
        return e2ee_required_error
      end

      unless valid_e2ee_payload?(payload)
        return e2ee_required_error
      end

      if !allow_files && files_present?(payload)
        return {
          message: 'File attachments are disabled for end-to-end encrypted private and direct channels',
          code: 'e2ee_files_not_supported',
          status: :unprocessable_entity
        }
      end

      nil
    end

    def e2ee_required_error
      {
        message: 'End-to-end encryption is required for private and direct messages. Upgrade your client.',
        code: LEGACY_UPGRADE_ERROR_CODE,
        status: :upgrade_required
      }
    end

    def bot_forbidden_error
      {
        message: 'Bot posting is disabled in end-to-end encrypted channels',
        code: BOT_FORBIDDEN_CODE,
        status: :forbidden
      }
    end

    private

    def files_present?(payload)
      payload_hash = payload.respond_to?(:to_h) ? payload.to_h.with_indifferent_access : {}.with_indifferent_access
      files = payload_hash[:files]
      return false if files.blank?
      return files.any? if files.respond_to?(:any?)

      true
    end

    def value_from_params(params, key)
      return nil unless params.present?

      if params.respond_to?(:[])
        value = params[key] || params[key.to_s]
        return value if value.present?
      end

      nil
    end
  end
end
