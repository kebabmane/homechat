class Api::V1::AuthController < Api::V1::BaseController
  # Skip authentication for these public endpoints
  skip_before_action :authenticate_api_request, only: [ :signin, :signup, :verify_2fa ]

  def signin
    user = User.find_by(username: params[:username])

    if user&.locked?
      audit_api_login_failure(user, "account_locked")
      return render_auth_failure
    end

    if user&.authenticate(params[:password])
      user.clear_failed_attempts!

      # M4: Locked accounts return the same generic error as bad credentials
      return render_auth_failure if user.locked?

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
        Rails.cache.write("2fa_temp_#{temp_token}", { user_id: user.id, attempts: 0 }, expires_in: 5.minutes)

        return render json: {
          success: false,
          requires_2fa: true,
          temp_token: temp_token
        }, status: :ok
      end

      # No 2FA, proceed with normal login
      complete_signin(user)
    else
      handle_api_failed_login(user)
      # M4: Unknown username, wrong password, or locked account all return the same response
      render_auth_failure
    end
  end

  def verify_2fa
    temp_token = params[:temp_token]
    code = params[:code]

    if temp_token.blank? || code.blank?
      return render json: { success: false, error: "Temporary token and verification code are required" }, status: :unprocessable_entity
    end

    cache_data = Rails.cache.read("2fa_temp_#{temp_token}")
    unless cache_data.is_a?(Hash)
      return render json: { success: false, error: "Invalid or expired session. Please sign in again." }, status: :unauthorized
    end

    user = User.find_by(id: cache_data[:user_id])
    unless user
      Rails.cache.delete("2fa_temp_#{temp_token}")
      return render json: { success: false, error: "Invalid or expired session. Please sign in again." }, status: :unauthorized
    end

    if user.verify_otp(code)
      Rails.cache.delete("2fa_temp_#{temp_token}")
      complete_signin(user)
    else
      attempts = cache_data[:attempts].to_i + 1
      if attempts >= 3
        Rails.cache.delete("2fa_temp_#{temp_token}")
        render json: { success: false, error: "Too many failed attempts. Please sign in again." }, status: :unauthorized
      else
        Rails.cache.write("2fa_temp_#{temp_token}", cache_data.merge(attempts: attempts), expires_in: 5.minutes)
        render json: { success: false, error: "Invalid verification code" }, status: :unauthorized
      end
    end
  end

  def signup
    unless Setting.registration_enabled?
      return render json: {
        success: false,
        error: "Registration is disabled on this server"
      }, status: :forbidden
    end

    # Check if signups require approval
    require_approval = Setting.fetch(:require_signup_approval, false)
    is_first_user = User.count == 0

    user = User.new(
      username: params[:username],
      password: params[:password],
      password_confirmation: params[:password_confirmation]
    )
    user.role = "admin" if is_first_user

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
        # User is approved, create token with full access and 90-day expiry
        api_token = ApiToken.create!(
          name: "Mobile App - #{user.username} - #{Time.current.to_f}",
          active: true,
          user: user,
          scopes: [ "user:profile", "user:channels", "user:messages" ],
          expires_at: 90.days.from_now
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
    current_api_token&.deactivate!
    render json: { success: true, message: "Signed out successfully" }
  end

  # POST /api/v1/auth/refresh
  # Issues a new 90-day token, deactivates the current one.
  def refresh
    # Reject if the current token is already expired
    if current_api_token.expired?
      return render json: { success: false, error: "Token has expired. Please sign in again." }, status: :unauthorized
    end

    old_token = current_api_token

    # Build a new token name derived from the old one, ensuring uniqueness
    new_name = "#{old_token.name} (refreshed #{Time.current.strftime('%Y-%m-%d %H:%M')})"

    new_token = ApiToken.create!(
      name: new_name,
      active: true,
      user: current_api_user,
      scopes: old_token.scopes,
      token_type: old_token.token_type,
      expires_at: 90.days.from_now
    )

    # Deactivate the old token after the new one is safely created
    old_token.deactivate!

    render json: { success: true, token: new_token.token }, status: :ok
  end

  # GET /api/v1/auth/sessions
  # Returns all active (non-expired) tokens for the current user.
  def sessions
    tokens = current_api_user
               .api_tokens
               .active
               .not_expired
               .order(Arel.sql("last_used_at DESC NULLS LAST"))

    serialized = tokens.map do |t|
      {
        id: t.id,
        name: t.name,
        token_prefix: "#{t.token_prefix}...",
        last_used_at: t.last_used_at&.iso8601,
        expires_at: t.expires_at&.iso8601,
        created_at: t.created_at.iso8601,
        is_current: t.id == current_api_token.id
      }
    end

    render json: { success: true, sessions: serialized }, status: :ok
  end

  # DELETE /api/v1/auth/sessions/:id
  # Deactivates a specific session token belonging to the current user.
  def revoke_session
    token = current_api_user.api_tokens.find_by(id: params[:id])

    unless token
      return render json: { success: false, error: "Session not found" }, status: :not_found
    end

    if token.id == current_api_token.id
      return render json: { success: false, error: "Cannot revoke your current session. Use signout instead." }, status: :unprocessable_entity
    end

    token.deactivate!

    render json: { success: true }, status: :ok
  end

  private

  def handle_api_failed_login(user)
    if user
      user.register_failed_attempt!
      audit_api_login_failure(user, "invalid_password", attempts: user.failed_attempts, locked: user.locked?)
    else
      audit_api_login_failure(nil, "user_not_found", username: params[:username])
    end
  end

  def audit_api_login_failure(user, reason, metadata = {})
    AuditLog.log(
      action: AuditLog::ACTIONS[:login_failed],
      resource: user,
      ip_address: request.remote_ip,
      user_agent: request.user_agent,
      metadata: { reason: reason }.merge(metadata)
    )
  rescue StandardError => e
    Rails.logger.debug "Failed to write API login failure audit log: #{e.class}"
  end

  # M4: Single auth failure helper — same JSON body and randomised timing for all failure paths
  # (wrong password, unknown username, locked account) to prevent user enumeration.
  def render_auth_failure
    sleep(rand(0.1..0.3))
    render json: { success: false, error: "invalid_credentials" }, status: :unauthorized
  end

  def complete_signin(user)
    user.clear_failed_attempts!

    # Issue a new API token for every sign-in so multiple devices can stay
    # logged in independently. The name includes a timestamp for uniqueness.
    api_token = ApiToken.create!(
      name: "Mobile App - #{user.username} - #{Time.current.to_f}",
      active: true,
      user: user,
      scopes: [ "user:profile", "user:channels", "user:messages" ],
      expires_at: 90.days.from_now
    )

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
