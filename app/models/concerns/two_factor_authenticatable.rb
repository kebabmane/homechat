# Concern for TOTP-based two-factor authentication
# Add to User model with: include TwoFactorAuthenticatable

module TwoFactorAuthenticatable
  extend ActiveSupport::Concern

  BACKUP_CODE_COUNT = 10
  BACKUP_CODE_LENGTH = 8

  included do
    serialize :otp_backup_codes, coder: JSON
  end

  def two_factor_available?
    has_attribute?(:otp_required_for_login) && has_attribute?(:otp_secret)
  end

  def two_factor_enabled?
    return false unless two_factor_available?
    otp_required_for_login && otp_secret.present?
  end

  def enable_two_factor!
    self.otp_secret = generate_otp_secret
    enable_two_factor_with_existing_secret!
    true
  end

  def enable_two_factor_with_existing_secret!
    raw_codes = generate_backup_codes  # sets self.otp_backup_codes to hashed digests internally
    self.otp_required_for_login = true
    save!

    AuditLog.log(
      action: AuditLog::ACTIONS[:two_factor_enabled],
      resource: self
    )

    raw_codes
  end

  def disable_two_factor!
    self.otp_secret = nil
    self.otp_backup_codes = nil
    self.otp_required_for_login = false
    save!

    AuditLog.log(
      action: AuditLog::ACTIONS[:two_factor_disabled],
      resource: self
    )

    true
  end

  def verify_otp(code)
    return false unless two_factor_enabled?
    return false if code.blank?

    # Clean up the code (remove spaces, dashes)
    code = code.to_s.gsub(/[\s-]/, "")

    # Try TOTP verification first
    if verify_totp(code)
      return true
    end

    # Try backup code verification
    if verify_backup_code(code)
      return true
    end

    false
  end

  def otp_provisioning_uri
    return nil if otp_secret.blank?

    issuer = Setting.fetch("site_name", "HomeChat")
    totp.provisioning_uri("#{username}@#{issuer}")
  end

  def otp_qr_code
    return nil unless otp_provisioning_uri

    RQRCode::QRCode.new(otp_provisioning_uri)
  end

  def regenerate_backup_codes!
    raw_codes = generate_backup_codes  # sets self.otp_backup_codes to hashed digests internally
    save!
    raw_codes
  end

  private

  def generate_otp_secret
    ROTP::Base32.random_base32
  end

  def generate_backup_codes
    raw_codes = BACKUP_CODE_COUNT.times.map { SecureRandom.alphanumeric(BACKUP_CODE_LENGTH).upcase }
    self.otp_backup_codes = raw_codes.map { |c| BCrypt::Password.create(c) }
    raw_codes  # return plaintext once for display; only hashes are persisted
  end

  def totp
    ROTP::TOTP.new(otp_secret, issuer: Setting.fetch("site_name", "HomeChat"))
  end

  def verify_totp(code)
    return false unless code.length == 6

    # Allow 30-second drift in either direction
    totp.verify(code, drift_behind: 30, drift_ahead: 30).present?
  end

  def verify_backup_code(code)
    return false unless otp_backup_codes.is_a?(Array)

    code = code.upcase.strip
    idx = otp_backup_codes.find_index { |digest| BCrypt::Password.new(digest) == code rescue false }
    return false unless idx

    self.otp_backup_codes = otp_backup_codes.reject.with_index { |_, i| i == idx }
    save!
    Rails.logger.info "Backup code used for user_id=#{id}. #{otp_backup_codes.length} remaining."
    true
  end
end
