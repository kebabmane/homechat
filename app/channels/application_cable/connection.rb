module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = find_verified_user
    end

    private

    def find_verified_user
      # For web clients using session
      if session_user = User.find_by(id: session[:user_id])
        session_user
      # For API clients using token
      elsif token_user = find_user_by_token
        token_user
      else
        reject_unauthorized_connection
      end
    end

    def find_user_by_token
      token = request.params[:token] || extract_bearer_token

      return nil unless token.present?

      # Validate API token and return associated user
      token_record = ApiToken.valid_token?(token)
      token_record&.user
    end

    def extract_bearer_token
      auth_header = request.headers['Authorization']
      return nil unless auth_header&.start_with?('Bearer ')
      auth_header.gsub(/^Bearer /, '')
    end

    def create_system_user
      password = SecureRandom.hex(16)
      User.create!(
        username: 'system',
        password: password,
        password_confirmation: password,
        role: 'user'
      )
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.warn "Failed to create system user for WebSocket: #{e.message}"
      User.find_by(username: 'system')
    end

    def session
      @session ||= request.session
    end
  end
end
