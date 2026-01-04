class TwoFactorSessionsController < ApplicationController
  layout 'authentication'

  before_action :require_pending_2fa, only: [:new, :create]

  def new
    @user = User.find_by(id: session[:pending_2fa_user_id])
  end

  def create
    @user = User.find_by(id: session[:pending_2fa_user_id])

    unless @user
      redirect_to signin_path, alert: 'Session expired. Please sign in again.'
      return
    end

    if @user.verify_otp(params[:otp_code])
      complete_sign_in(@user)
    else
      AuditLog.log(
        action: AuditLog::ACTIONS[:login_failed],
        resource: @user,
        ip_address: request.remote_ip,
        user_agent: request.user_agent,
        metadata: { reason: "invalid_2fa_code" }
      )

      flash.now[:alert] = 'Invalid verification code'
      render :new, status: :unprocessable_content
    end
  end

  private

  def require_pending_2fa
    unless session[:pending_2fa_user_id].present?
      redirect_to signin_path, alert: 'Please sign in first.'
    end
  end

  def complete_sign_in(user)
    session.delete(:pending_2fa_user_id)
    session[:user_id] = user.id
    session[:last_activity] = Time.current.to_s

    user.clear_failed_attempts!

    AuditLog.log(
      action: AuditLog::ACTIONS[:login_success],
      user: user,
      resource: user,
      ip_address: request.remote_ip,
      user_agent: request.user_agent,
      metadata: { two_factor: true }
    )

    redirect_to dashboard_path
  end
end
