class SessionsController < ApplicationController
  layout "authentication"

  def new
  end

  def create
    user = User.find_by(username: params[:username])

    # Check if account is locked
    if user&.locked?
      remaining = user.lockout_remaining_time
      flash.now[:alert] = "Account is locked. Try again in #{remaining} minutes."
      AuditLog.log(
        action: AuditLog::ACTIONS[:login_failed],
        resource: user,
        ip_address: request.remote_ip,
        user_agent: request.user_agent,
        metadata: { reason: "account_locked", username: params[:username] }
      )
      render :new, status: :unprocessable_content
      return
    end

    if user&.authenticate(params[:password])
      # Check for 2FA requirement
      if user.two_factor_enabled?
        session[:pending_2fa_user_id] = user.id
        redirect_to new_two_factor_session_path
        return
      end

      complete_sign_in(user)
    else
      handle_failed_login(user)
    end
  end

  def destroy
    AuditLog.log(
      action: AuditLog::ACTIONS[:logout],
      user: current_user,
      resource: current_user,
      ip_address: request.remote_ip,
      user_agent: request.user_agent
    ) if current_user

    session[:user_id] = nil
    redirect_to root_path
  end

  private

  def complete_sign_in(user)
    user.clear_failed_attempts!
    session[:user_id] = user.id
    session[:last_activity] = Time.current.to_s

    AuditLog.log(
      action: AuditLog::ACTIONS[:login_success],
      user: user,
      resource: user,
      ip_address: request.remote_ip,
      user_agent: request.user_agent
    )

    redirect_to dashboard_path
  end

  def handle_failed_login(user)
    if user
      user.register_failed_attempt!

      if user.locked?
        flash.now[:alert] = "Account is locked. Try again in 15 minutes."
      else
        flash.now[:alert] = "Invalid username or password."
      end

      AuditLog.log(
        action: AuditLog::ACTIONS[:login_failed],
        resource: user,
        ip_address: request.remote_ip,
        user_agent: request.user_agent,
        metadata: {
          reason: "invalid_password",
          attempts: user.failed_attempts,
          locked: user.locked?
        }
      )
    else
      flash.now[:alert] = "Invalid username or password"

      AuditLog.log(
        action: AuditLog::ACTIONS[:login_failed],
        resource: nil,
        ip_address: request.remote_ip,
        user_agent: request.user_agent,
        metadata: { reason: "user_not_found", username: params[:username] }
      )
    end

    render :new, status: :unprocessable_content
  end
end
