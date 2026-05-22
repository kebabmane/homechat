class Api::V1::UserKeysController < Api::V1::BaseController
  # PUT /api/v1/me/hmac_key
  # Upsert the current user's encrypted HMAC key.
  def update_hmac_key
    encrypted_hmac_key = params[:encrypted_hmac_key]
    key_version = params[:key_version].presence || "1"

    if encrypted_hmac_key.blank?
      return render json: { success: false, error: "encrypted_hmac_key is required" }, status: :unprocessable_entity
    end

    key_record = UserKey.find_or_initialize_by(user_id: current_api_user.id)
    key_record.assign_attributes(encrypted_hmac_key: encrypted_hmac_key, key_version: key_version)

    if key_record.save
      render json: { success: true }, status: :ok
    else
      render json: { success: false, errors: key_record.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # GET /api/v1/me/hmac_key
  # Retrieve the current user's encrypted HMAC key.
  def get_hmac_key
    key_record = UserKey.find_by(user_id: current_api_user.id)

    unless key_record
      return render json: { success: false, error: "HMAC key not found" }, status: :not_found
    end

    render json: {
      encrypted_hmac_key: key_record.encrypted_hmac_key,
      key_version: key_record.key_version
    }, status: :ok
  end
end
