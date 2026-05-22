class PasswordResetsController < ApplicationController
  layout "authentication"

  skip_before_action :require_login, only: [ :edit, :update ], raise: false
  skip_before_action :mark_active, only: [ :edit, :update ], raise: false
  skip_before_action :set_sidebar_data, only: [ :edit, :update ], raise: false

  def edit
    @user = find_user_by_token
    if @user.nil?
      flash[:alert] = "Invalid or expired reset link."
      redirect_to signin_path
    end
  end

  def update
    @user = find_user_by_token
    if @user.nil?
      flash[:alert] = "Invalid or expired reset link."
      redirect_to signin_path
      return
    end

    # Consume the token before updating to prevent reuse on concurrent requests (M3).
    @user.clear_password_reset_token!

    if @user.update(password_params)
      # Invalidate all existing web sessions for this user (M4).
      reset_session

      AuditLog.log(
        action: "user.password_reset",
        user: @user,
        resource: @user,
        ip_address: request.remote_ip,
        user_agent: request.user_agent
      )

      flash[:notice] = "Password updated successfully. Please sign in."
      redirect_to signin_path
    else
      # Token already consumed — regenerate so the edit form is still usable.
      new_token = @user.generate_password_reset_token!
      redirect_to edit_password_reset_path(token: new_token), alert: @user.errors.full_messages.to_sentence
    end
  end

  private

  def find_user_by_token
    return nil if params[:token].blank?

    selector, verifier = params[:token].to_s.split(".", 2)
    return nil if selector.blank? || verifier.blank?

    user = User.find_by(password_reset_token_selector: selector)
    return nil unless user&.password_reset_token_valid?(params[:token])

    user
  end

  def password_params
    params.require(:user).permit(:password, :password_confirmation)
  end
end
