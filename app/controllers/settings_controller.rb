class SettingsController < ApplicationController
  before_action :require_login

  def edit
  end

  def update
    if current_user.update(user_params)
      redirect_to edit_settings_path, notice: 'Settings updated successfully.'
    else
      flash.now[:alert] = 'Could not update settings.'
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.require(:user).permit(:username, :password, :password_confirmation, :avatar)
  end
end
