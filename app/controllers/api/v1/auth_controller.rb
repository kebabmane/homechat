class Api::V1::AuthController < Api::V1::BaseController
  # Skip authentication for these public endpoints
  skip_before_action :authenticate_api_request, only: [:signin, :signup]

  def signin
    user = User.find_by(username: params[:username])

    if user&.authenticate(params[:password])
      # Create or find an API token for this user
      api_token = ApiToken.find_by(name: "Mobile App - #{user.username}")

      if api_token.nil?
        # Create new token
        api_token = ApiToken.create!(name: "Mobile App - #{user.username}", active: true)
      elsif !api_token.active?
        # Reactivate existing token
        api_token.update!(active: true)
        api_token.regenerate!
      else
        # Regenerate token for existing active token to ensure we have the plain text
        api_token.regenerate!
      end

      render json: {
        success: true,
        user: {
          id: user.id,
          username: user.username,
          role: user.role
        },
        token: api_token.token
      }, status: :ok
    else
      render json: {
        success: false,
        error: "Invalid username or password"
      }, status: :unauthorized
    end
  end

  def signup
    user = User.new(
      username: params[:username],
      password: params[:password],
      password_confirmation: params[:password_confirmation]
    )

    if user.save
      # Create an API token for the new user
      api_token = ApiToken.create!(name: "Mobile App - #{user.username}", active: true)

      render json: {
        success: true,
        user: {
          id: user.id,
          username: user.username,
          role: user.role
        },
        token: api_token.token
      }, status: :created
    else
      render json: {
        success: false,
        errors: user.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  def signout
    # For API clients, we would typically invalidate the token
    # Since we're using simple bearer tokens, we'll just return success
    # In a more robust implementation, we'd maintain a token blacklist
    render json: { success: true, message: "Signed out successfully" }
  end
end