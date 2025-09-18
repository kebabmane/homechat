class Api::V1::FcmController < Api::V1::BaseController
  # PUT /api/v1/fcm_token
  def update_token
    token = params[:token]&.strip

    if token.blank?
      render_error('FCM token is required', :bad_request)
      return
    end

    user = current_api_user

    begin
      user.update!(fcm_token: token)
      Rails.logger.info "Updated FCM token for user #{user.username} (ID: #{user.id})"

      render_success({
        message: 'FCM token updated successfully',
        user_id: user.id
      })

    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error "Failed to update FCM token for user #{user.id}: #{e.message}"
      render_error("Failed to update FCM token: #{e.message}", :unprocessable_entity)
    rescue StandardError => e
      Rails.logger.error "Unexpected error updating FCM token: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      render_error('Internal server error', :internal_server_error)
    end
  end
end