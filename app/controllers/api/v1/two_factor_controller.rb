class Api::V1::TwoFactorController < Api::V1::BaseController
  # GET /api/v1/2fa/status
  def status
    render json: {
      enabled: current_api_user.two_factor_enabled?,
      available: current_api_user.two_factor_available?
    }
  end

  # POST /api/v1/2fa/setup
  # Generates a new secret and returns the provisioning URI for QR code
  def setup
    if current_api_user.two_factor_enabled?
      return render json: { error: "Two-factor authentication is already enabled" }, status: :unprocessable_entity
    end

    # Generate a new secret but don't enable yet
    current_api_user.otp_secret = ROTP::Base32.random_base32
    current_api_user.save!

    render json: {
      provisioning_uri: current_api_user.otp_provisioning_uri,
      secret: current_api_user.otp_secret
    }
  end

  # POST /api/v1/2fa/verify
  # Verifies the code and enables 2FA
  def verify
    code = params[:code]

    if code.blank?
      return render json: { error: "Verification code is required" }, status: :unprocessable_entity
    end

    if current_api_user.otp_secret.blank?
      return render json: { error: "Please setup 2FA first" }, status: :unprocessable_entity
    end

    # Verify the code using the pending secret
    totp = ROTP::TOTP.new(current_api_user.otp_secret, issuer: Setting.fetch("site_name", "HomeChat"))
    if totp.verify(code.to_s.gsub(/[\s-]/, ""), drift_behind: 30, drift_ahead: 30)
      # Code is valid, enable 2FA and persist only BCrypt digests.
      backup_codes = current_api_user.enable_two_factor_with_existing_secret!

      render json: {
        success: true,
        backup_codes: backup_codes,
        message: "Two-factor authentication has been enabled. Save your backup codes!"
      }
    else
      render json: { error: "Invalid verification code" }, status: :unprocessable_entity
    end
  end

  # POST /api/v1/2fa/disable
  # Disables 2FA (requires password and TOTP code)
  def disable
    password = params[:password]
    code = params[:code]

    if password.blank? || code.blank?
      return render json: { error: "Password and verification code are required" }, status: :unprocessable_entity
    end

    unless current_api_user.authenticate(password)
      return render json: { error: "Invalid password" }, status: :unprocessable_entity
    end

    unless current_api_user.verify_otp(code)
      return render json: { error: "Invalid verification code" }, status: :unprocessable_entity
    end

    current_api_user.disable_two_factor!

    render json: {
      success: true,
      message: "Two-factor authentication has been disabled"
    }
  end

  # GET /api/v1/2fa/backup_codes
  # Returns backup codes (requires TOTP verification)
  def backup_codes
    code = params[:code]

    if code.blank?
      return render json: { error: "Verification code is required" }, status: :unprocessable_entity
    end

    unless current_api_user.verify_otp(code)
      return render json: { error: "Invalid verification code" }, status: :unprocessable_entity
    end

    render json: {
      success: true,
      remaining_count: current_api_user.otp_backup_codes&.length || 0
    }
  end

  # POST /api/v1/2fa/regenerate_backup_codes
  # Generates new backup codes (requires TOTP verification)
  def regenerate_backup_codes
    code = params[:code]

    if code.blank?
      return render json: { error: "Verification code is required" }, status: :unprocessable_entity
    end

    unless current_api_user.verify_otp(code)
      return render json: { error: "Invalid verification code" }, status: :unprocessable_entity
    end

    new_codes = current_api_user.regenerate_backup_codes!

    render json: {
      success: true,
      backup_codes: new_codes,
      message: "Backup codes have been regenerated. Save your new codes!"
    }
  end
end
