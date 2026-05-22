class Api::V1::UsersController < Api::V1::BaseController
  before_action :require_non_bot_token
  before_action -> { require_scope("user:profile") }

  # GET /api/v1/me
  def me
    render json: profile_payload(current_api_user)
  end

  # PATCH /api/v1/me
  # Update profile (username, timezone, avatar).
  # Changing username requires current password re-authentication.
  def update
    update_params = profile_params

    # Sensitive change: username modification requires current password
    if update_params[:username].present? && update_params[:username] != current_api_user.username
      current_password = params[:current_password]
      if current_password.blank?
        return render json: { success: false, error: "Current password is required to change username" }, status: :unprocessable_entity
      end
      unless current_api_user.authenticate(current_password)
        return render json: { success: false, error: "Current password is incorrect" }, status: :unprocessable_entity
      end
    end

    if current_api_user.update(update_params)
      render json: {
        success: true,
        user: profile_payload(current_api_user),
        message: "Profile updated successfully"
      }
    else
      render json: {
        success: false,
        errors: current_api_user.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # POST /api/v1/me/change_password
  # Change password - requires current password
  def change_password
    current_password = params[:current_password]
    new_password = params[:new_password]
    new_password_confirmation = params[:new_password_confirmation]

    if current_password.blank?
      return render json: { success: false, error: "Current password is required" }, status: :unprocessable_entity
    end

    if new_password.blank?
      return render json: { success: false, error: "New password is required" }, status: :unprocessable_entity
    end

    unless current_api_user.authenticate(current_password)
      return render json: { success: false, error: "Current password is incorrect" }, status: :unprocessable_entity
    end

    if current_api_user.update(password: new_password, password_confirmation: new_password_confirmation)
      AuditLog.log(
        action: AuditLog::ACTIONS[:password_changed],
        resource: current_api_user
      )

      render json: {
        success: true,
        message: "Password changed successfully"
      }
    else
      render json: {
        success: false,
        errors: current_api_user.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # DELETE /api/v1/me/avatar
  # Remove avatar
  def remove_avatar
    if current_api_user.avatar.attached?
      current_api_user.avatar.purge
      render json: { success: true, message: "Avatar removed successfully" }
    else
      render json: { success: false, error: "No avatar to remove" }, status: :unprocessable_entity
    end
  end

  private

  def profile_params
    params.permit(:username, :timezone, :avatar)
  end

  def profile_payload(user)
    {
      id: user.id,
      username: user.username,
      role: user.role,
      timezone: user.timezone,
      two_factor_enabled: user.two_factor_enabled?,
      avatar_url: user.avatar.attached? ? rails_blob_url(user.avatar, host: request.base_url) : nil,
      avatar_initials: user.avatar_initials,
      avatar_color_index: user.avatar_color_index,
      created_at: user.created_at&.iso8601
    }
  end
end
