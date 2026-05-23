class Api::V1::FcmController < Api::V1::BaseController
  # PUT /api/v1/fcm_token
  def update_token
    token = (params[:token].presence || params[:fcm_token].presence)&.strip

    if token.blank?
      render_error("FCM token is required", :bad_request)
      return
    end

    user = current_api_user

    begin
      user.update!(fcm_token: token)
      Rails.logger.info "Updated FCM token for user_id=#{user.id}"

      render_success({
        message: "FCM token updated successfully",
        user_id: user.id
      })

    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error "Failed to update FCM token for user #{user.id}: #{e.class}"
      render_error("Failed to update FCM token: #{e.message}", :unprocessable_entity)
    rescue StandardError => e
      Rails.logger.error "Unexpected error updating FCM token: #{e.class}"
      Rails.logger.error e.backtrace.join("\n")
      render_error("Internal server error", :internal_server_error)
    end
  end

  # DELETE /api/v1/fcm_token
  def destroy_token
    current_api_user.update!(fcm_token: nil)
    render_success({ message: "FCM token removed successfully", user_id: current_api_user.id })
  rescue ActiveRecord::RecordInvalid => e
    render_error("Failed to remove FCM token: #{e.message}", :unprocessable_entity)
  end
end
