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
      return nil unless request.params[:token].present?

      # Find user by API token (from BotToken model)
      bot_token = BotToken.active.find_by(token: request.params[:token])
      bot_token&.user
    end

    def session
      @session ||= request.session
    end
  end
end
