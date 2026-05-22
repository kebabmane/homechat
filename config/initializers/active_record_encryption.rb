# Configure ActiveRecord Encryption for sensitive data
# This provides at-rest encryption for webhook secrets and other sensitive fields
#
# 1.3: AR Encryption keys are independent of SECRET_KEY_BASE so that rotating the secret
# (e.g., after a compromise) does not break access to previously encrypted data.
#
# To generate independent keys:
#   rails credentials:edit
#   ar_encryption:
#     primary_key: <%= SecureRandom.hex(32) %>
#     deterministic_key: <%= SecureRandom.hex(32) %>
#     key_derivation_salt: <%= SecureRandom.hex(32) %>
#
# Or via environment variables: AR_ENCRYPTION_PRIMARY_KEY, AR_ENCRYPTION_DETERMINISTIC_KEY,
# AR_ENCRYPTION_KEY_DERIVATION_SALT

Rails.application.configure do
  primary_key = Rails.application.credentials.dig(:ar_encryption, :primary_key) ||
                ENV["AR_ENCRYPTION_PRIMARY_KEY"]
  deterministic_key = Rails.application.credentials.dig(:ar_encryption, :deterministic_key) ||
                      ENV["AR_ENCRYPTION_DETERMINISTIC_KEY"]
  key_derivation_salt = Rails.application.credentials.dig(:ar_encryption, :key_derivation_salt) ||
                        ENV["AR_ENCRYPTION_KEY_DERIVATION_SALT"]

  if primary_key.present? && deterministic_key.present? && key_derivation_salt.present?
    config.active_record.encryption.primary_key = primary_key
    config.active_record.encryption.deterministic_key = deterministic_key
    config.active_record.encryption.key_derivation_salt = key_derivation_salt
    Rails.logger.info "ActiveRecord Encryption: using independent credential keys (SECRET_KEY_BASE rotation safe)"
  else
    # M1: In production, missing independent keys is a fatal misconfiguration.
    # Rotating SECRET_KEY_BASE would break access to all encrypted data.
    if Rails.env.production?
      raise "ActiveRecord Encryption misconfigured: AR_ENCRYPTION_PRIMARY_KEY, " \
            "AR_ENCRYPTION_DETERMINISTIC_KEY, and AR_ENCRYPTION_KEY_DERIVATION_SALT must all be set " \
            "in credentials (ar_encryption:) or environment variables. " \
            "Falling back to SECRET_KEY_BASE derivation is not permitted in production."
    end

    # Non-production fallback: derive keys from SECRET_KEY_BASE for development convenience.
    # WARNING: rotating SECRET_KEY_BASE will break access to encrypted data while this path is active.
    secret_key_base = Rails.application.secret_key_base || ENV["SECRET_KEY_BASE"]

    if secret_key_base.present?
      config.active_record.encryption.primary_key =
        OpenSSL::HMAC.hexdigest("SHA256", secret_key_base, "active_record_encryption_primary_key")[0, 32]
      config.active_record.encryption.deterministic_key =
        OpenSSL::HMAC.hexdigest("SHA256", secret_key_base, "active_record_encryption_deterministic_key")[0, 32]
      config.active_record.encryption.key_derivation_salt =
        OpenSSL::HMAC.hexdigest("SHA256", secret_key_base, "active_record_encryption_key_derivation_salt")[0, 32]

      Rails.logger.warn "ActiveRecord Encryption: falling back to SECRET_KEY_BASE derivation (non-production only). " \
                        "Set ar_encryption credentials or AR_ENCRYPTION_* env vars for production use."
    else
      Rails.logger.warn "ActiveRecord Encryption: No keys configured, encryption disabled"
    end
  end

  # Support unencrypted data during migration period.
  # Set to false after all data has been re-encrypted with independent keys.
  config.active_record.encryption.support_unencrypted_data = true
end
