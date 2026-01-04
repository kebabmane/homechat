# Concern for TOTP-based two-factor authentication
# Add to User model with: include TwoFactorAuthenticatable

module TwoFactorAuthenticatable
  extend ActiveSupport::Concern

  BACKUP_CODE_COUNT = 10
  BACKUP_CODE_LENGTH = 8

  included do
    # Encrypt backup codes before saving (only if column exists)
    serialize :otp_backup_codes, coder: JSON if column_names.include?('otp_backup_codes')
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
    self.otp_backup_codes = generate_backup_codes
    self.otp_required_for_login = true
    save!

    AuditLog.log(
      action: AuditLog::ACTIONS[:two_factor_enabled],
      resource: self
    )

    true
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
    return nil unless otp_secret.present?

    issuer = Setting.fetch("site_name", "HomeChat")
    totp.provisioning_uri("#{username}@#{issuer}", issuer: issuer)
  end

  def otp_qr_code
    return nil unless otp_provisioning_uri

    RQRCode::QRCode.new(otp_provisioning_uri)
  end

  def regenerate_backup_codes!
    self.otp_backup_codes = generate_backup_codes
    save!
    otp_backup_codes
  end

  private

  def generate_otp_secret
    ROTP::Base32.random_base32
  end

  def generate_backup_codes
    BACKUP_CODE_COUNT.times.map do
      SecureRandom.alphanumeric(BACKUP_CODE_LENGTH).upcase
    end
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

    code = code.upcase
    if otp_backup_codes.include?(code)
      # Remove used backup code
      self.otp_backup_codes = otp_backup_codes - [code]
      save!
      Rails.logger.info "Backup code used for user #{username}. #{otp_backup_codes.length} remaining."
      true
    else
      false
    end
  end
end
