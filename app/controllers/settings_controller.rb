class SettingsController < ApplicationController
  before_action :require_login

  def edit
  end

  def update
    # Verify current password for security
    current_password = params[:user]&.dig(:current_password)

    if current_password.blank?
      flash.now[:alert] = 'Current password is required to update settings.'
      render :edit, status: :unprocessable_content
      return
    end

    unless current_user.authenticate(current_password)
      flash.now[:alert] = 'Current password is incorrect.'
      render :edit, status: :unprocessable_content
      return
    end

    # Filter out blank password fields and current_password (not a user attribute)
    filtered_params = user_params.reject { |key, value|
      key == 'current_password' || ((key == 'password' || key == 'password_confirmation') && value.blank?)
    }

    if current_user.update(filtered_params)
      redirect_to edit_settings_path, notice: 'Settings updated successfully.'
    else
      flash.now[:alert] = 'Could not update settings.'
      render :edit, status: :unprocessable_content
    end
  end

  private

  def user_params
    params.require(:user).permit(:username, :password, :password_confirmation, :avatar, :current_password)
  end
end
