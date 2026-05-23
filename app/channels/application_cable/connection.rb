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
      # Only allow Authorization: Bearer header tokens (no query param fallback)
      token = extract_bearer_token

      return nil if token.blank?

      # Validate API token and return associated user
      token_record = ApiToken.valid_token?(token)
      # L5: Store token ID so channels can do periodic re-validation
      @current_api_token_id = token_record&.id
      token_record&.user
    end

    public

    # L5: Exposes the token record ID to channels for periodic re-validation.
    # Returns nil for session-based (web) connections.
    def current_api_token_id
      @current_api_token_id
    end

    private

    def extract_bearer_token
      auth_header = request.headers["Authorization"]
      return nil unless auth_header&.start_with?("Bearer ")

      auth_header.gsub(/^Bearer /, "")
    end

    def create_system_user
      password = SecureRandom.hex(16)
      User.create!(
        username: "system",
        password: password,
        password_confirmation: password,
        role: "user"
      )
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.warn "Failed to create system user for WebSocket: #{e.class}"
      User.find_by(username: "system")
    end

    def session
      @session ||= request.session
    end
  end
end
