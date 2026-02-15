class TwoFactorSettingsController < ApplicationController
  before_action :require_login
  before_action :verify_password, only: [:create, :destroy]

  def show
    @two_factor_enabled = current_user.two_factor_enabled?
  end

  def new
    if current_user.two_factor_enabled?
      redirect_to two_factor_settings_path, notice: 'Two-factor authentication is already enabled.'
      return
    end

    # Generate a new secret for setup
    current_user.otp_secret = ROTP::Base32.random_base32
    current_user.save!

    @qr_code = current_user.otp_qr_code
    @otp_secret = current_user.otp_secret
  end

  def create
    if current_user.two_factor_enabled?
      redirect_to two_factor_settings_path, alert: 'Two-factor authentication is already enabled.'
      return
    end

    if current_user.verify_otp(params[:otp_code])
      current_user.otp_required_for_login = true
      current_user.otp_backup_codes = current_user.send(:generate_backup_codes)
      current_user.save!

      AuditLog.log(
        action: AuditLog::ACTIONS[:two_factor_enabled],
        user: current_user,
        resource: current_user,
        ip_address: request.remote_ip,
        user_agent: request.user_agent
      )

      @backup_codes = current_user.otp_backup_codes
      render :backup_codes
    else
      flash.now[:alert] = 'Invalid verification code. Please try again.'
      @qr_code = current_user.otp_qr_code
      @otp_secret = current_user.otp_secret
      render :new, status: :unprocessable_content
    end
  end

  def destroy
    unless current_user.two_factor_enabled?
      redirect_to two_factor_settings_path, alert: 'Two-factor authentication is not enabled.'
      return
    end

    current_user.disable_two_factor!

    redirect_to two_factor_settings_path, notice: 'Two-factor authentication has been disabled.'
  end

  def regenerate_backup_codes
    unless current_user.two_factor_enabled?
      redirect_to two_factor_settings_path, alert: 'Two-factor authentication is not enabled.'
      return
    end

    @backup_codes = current_user.regenerate_backup_codes!
    render :backup_codes
  end

  private

  def verify_password
    unless current_user.authenticate(params[:password])
      redirect_to two_factor_settings_path, alert: 'Invalid password.'
    end
  end
end
