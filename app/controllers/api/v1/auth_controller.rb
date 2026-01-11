class Api::V1::AuthController < Api::V1::BaseController
  # Skip authentication for these public endpoints
  skip_before_action :authenticate_api_request, only: [:signin, :signup, :verify_2fa]

  def signin
    user = User.find_by(username: params[:username])

    if user&.authenticate(params[:password])
      # Check if user is pending approval
      if user.pending_approval?
        return render json: {
          success: false,
          pending_approval: true,
          error: "Your account is pending approval by an administrator"
        }, status: :forbidden
      end

      # Check if 2FA is enabled
      if user.two_factor_enabled?
        # Generate a temporary token for 2FA verification
        temp_token = SecureRandom.hex(32)
        Rails.cache.write("2fa_temp_#{temp_token}", user.id, expires_in: 5.minutes)

        return render json: {
          success: false,
          requires_2fa: true,
          temp_token: temp_token
        }, status: :ok
      end

      # No 2FA, proceed with normal login
      complete_signin(user)
    else
      render json: {
        success: false,
        error: "Invalid username or password"
      }, status: :unauthorized
    end
  end

  def verify_2fa
    temp_token = params[:temp_token]
    code = params[:code]

    if temp_token.blank? || code.blank?
      return render json: { success: false, error: "Temporary token and verification code are required" }, status: :unprocessable_entity
    end

    user_id = Rails.cache.read("2fa_temp_#{temp_token}")
    unless user_id
      return render json: { success: false, error: "Invalid or expired session. Please sign in again." }, status: :unauthorized
    end

    user = User.find_by(id: user_id)
    unless user
      return render json: { success: false, error: "User not found" }, status: :unauthorized
    end

    if user.verify_otp(code)
      # Clear the temp token
      Rails.cache.delete("2fa_temp_#{temp_token}")

      # Complete the signin
      complete_signin(user)
    else
      render json: { success: false, error: "Invalid verification code" }, status: :unauthorized
    end
  end

  def signup
    # Check if signups require approval
    require_approval = Setting.fetch(:require_signup_approval, false)
    is_first_user = User.count == 0

    user = User.new(
      username: params[:username],
      password: params[:password],
      password_confirmation: params[:password_confirmation]
    )

    # First user or approval not required = auto-approved
    # Otherwise, user starts as unapproved
    if is_first_user || !require_approval
      user.approved = true
      user.approved_at = Time.current
    else
      user.approved = false
    end

    if user.save
      # Check if user needs approval
      if user.pending_approval?
        render json: {
          success: true,
          pending_approval: true,
          message: "Your account has been created and is pending approval by an administrator"
        }, status: :created
      else
        # User is approved, create token with full access
        api_token = ApiToken.create!(
          name: "Mobile App - #{user.username}",
          active: true,
          user: user,
          scopes: nil  # nil = legacy full access for mobile apps
        )

        render json: {
          success: true,
          user: {
            id: user.id,
            username: user.username,
            role: user.role
          },
          token: api_token.token
        }, status: :created
      end
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

  private

  def complete_signin(user)
    # Create or find an API token for this user
    api_token = ApiToken.find_by(name: "Mobile App - #{user.username}")

    if api_token.nil?
      # Create new token linked to the user with full user scopes
      api_token = ApiToken.create!(
        name: "Mobile App - #{user.username}",
        active: true,
        user: user,
        scopes: nil  # nil = legacy full access for mobile apps
      )
    elsif !api_token.active?
      # Reactivate existing token and ensure it's linked to the user
      api_token.update!(active: true, user: user, scopes: nil)
      api_token.regenerate!
    else
      # Regenerate token for existing active token and ensure user link
      api_token.update!(user: user, scopes: nil)
      api_token.regenerate!
    end

    render json: {
      success: true,
      user: {
        id: user.id,
        username: user.username,
        role: user.role,
        two_factor_enabled: user.two_factor_enabled?
      },
      token: api_token.token
    }, status: :ok
  end
end