class SettingsController < ApplicationController
  before_action :require_login

  def edit
  end

  def mobile_setup
    @server_config = build_server_configuration
    @setup_token = generate_setup_token
    @qr_payload = @server_config.to_qr_payload(token: @setup_token)
    @qr_code = RQRCode::QRCode.new(@qr_payload)
  end

  def update
    # Filter out blank password fields and current_password (not a user attribute)
    filtered_params = user_params.reject { |key, value|
      key == 'current_password' || ((key == 'password' || key == 'password_confirmation') && value.blank?)
    }

    # Only require current password when changing password
    if filtered_params['password'].present?
      current_password = params[:user]&.dig(:current_password)

      if current_password.blank?
        flash.now[:alert] = 'Current password is required to change your password.'
        render :edit, status: :unprocessable_content
        return
      end

      unless current_user.authenticate(current_password)
        flash.now[:alert] = 'Current password is incorrect.'
        render :edit, status: :unprocessable_content
        return
      end
    end

    if current_user.update(filtered_params)
      redirect_to edit_settings_path, notice: 'Settings updated successfully.'
    else
      flash.now[:alert] = 'Could not update settings.'
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    # Handle avatar removal
    if params[:remove_avatar] && current_user.avatar.attached?
      current_user.avatar.purge
      redirect_to edit_settings_path, notice: 'Avatar removed successfully.'
    else
      redirect_to edit_settings_path, alert: 'Could not remove avatar.'
    end
  end

  private

  def user_params
    params.require(:user).permit(:username, :password, :password_confirmation, :avatar, :current_password, :timezone)
  end

  def build_server_configuration
    ServerConfiguration.new(
      host: request.host,
      port: request.port,
      use_ssl: request.ssl?,
      server_name: Rails.application.config.discovery.server_name || "HomeChat on #{Socket.gethostname}"
    )
  end

  def generate_setup_token
    # Create a time-limited setup token (valid for 10 minutes)
    # This is separate from API tokens - it's used only for initial mobile app setup
    payload = {
      user_id: current_user.id,
      purpose: 'mobile_setup',
      exp: 10.minutes.from_now.to_i
    }
    Base64.urlsafe_encode64(payload.to_json)
  end
end
