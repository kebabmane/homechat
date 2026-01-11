class PasswordResetsController < ApplicationController
  layout 'authentication'

  skip_before_action :require_login, only: [:edit, :update]
  skip_before_action :mark_active, only: [:edit, :update], raise: false
  skip_before_action :set_sidebar_data, only: [:edit, :update], raise: false

  def edit
    @user = find_user_by_token
    if @user.nil?
      flash[:alert] = 'Invalid or expired reset link.'
      redirect_to signin_path
    end
  end

  def update
    @user = find_user_by_token
    if @user.nil?
      flash[:alert] = 'Invalid or expired reset link.'
      redirect_to signin_path
      return
    end

    if @user.update(password_params)
      @user.clear_password_reset_token!

      AuditLog.log(
        action: 'user.password_reset',
        user: @user,
        resource: @user,
        ip_address: request.remote_ip,
        user_agent: request.user_agent
      )

      flash[:notice] = 'Password updated successfully. Please sign in.'
      redirect_to signin_path
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def find_user_by_token
    return nil if params[:token].blank?

    User.find_each do |user|
      return user if user.password_reset_token_valid?(params[:token])
    end
    nil
  end

  def password_params
    params.require(:user).permit(:password, :password_confirmation)
  end
end
