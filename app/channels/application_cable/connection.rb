module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user, :client_type

    def connect
      self.current_user = find_verified_user
      self.client_type = request.params[:client_type] || 'web'

      Rails.logger.info "ActionCable connection established: User #{current_user.id} (#{current_user.username}) via #{client_type}"
    end

    private

    def find_verified_user
      # For web clients: authenticate via session
      if verified_user = find_user_from_session
        return verified_user
      end

      # For API clients: authenticate via token parameter
      if verified_user = find_user_from_token
        return verified_user
      end

      # Reject unauthorized connections
      Rails.logger.warn "ActionCable connection rejected: No valid authentication found"
      reject_unauthorized_connection
    end

    def find_user_from_session
      # ActionCable doesn't have direct session access, but we can get it from cookies
      # The session is stored in the encrypted cookie
      return nil unless request.session.present?

      user_id = request.session[:user_id]
      return nil unless user_id

      user = User.find_by(id: user_id)
      if user
        Rails.logger.debug "ActionCable authenticated via session: #{user.username}"
        return user
      end

      nil
    end

    def find_user_from_token
      token = request.params[:token]
      return nil if token.blank?

      # Validate API token and get system user
      if ApiToken.valid_token?(token)
        system_user = User.find_by(username: 'system') || create_system_user
        Rails.logger.debug "ActionCable authenticated via API token: system user"
        return system_user
      end

      nil
    end

    def create_system_user
      Rails.logger.info "Creating system user for API connections"
      User.create!(
        username: 'system',
        password: SecureRandom.hex(32),
        password_confirmation: SecureRandom.hex(32),
        role: 'user'
      )
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error "Failed to create system user: #{e.message}"
      User.find_by(username: 'system')
    end
  end
end

