class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Configure CSRF protection for all environments
  protect_from_forgery with: :exception, unless: :home_assistant_verified?
  before_action :verify_home_assistant_origin, if: :home_assistant_addon?

  layout :determine_layout
  before_action :set_sidebar_data, if: :logged_in?
  before_action :mark_active, if: :logged_in?
  before_action :check_session_timeout, if: :logged_in?
  around_action :set_user_timezone, if: :logged_in?

  helper_method :current_user, :logged_in?

  private

  def current_user
    return @current_user if defined?(@current_user)

    @current_user = session[:user_id] ? User.find_by(id: session[:user_id]) : nil
    session.delete(:user_id) unless @current_user
    @current_user
  end

  def logged_in?
    !!current_user
  end

  def require_login
    unless logged_in?
      redirect_to signin_path, alert: "Please sign in to continue"
    end
  end

  def determine_layout
    logged_in? ? "application" : "authentication"
  end

  def set_sidebar_data
    @sidebar_public_channels = Channel.public_channels.limit(10).to_a
    # Show only non-DM channels in the Channels section
    @sidebar_my_channels = current_user.channels.where.not(channel_type: "dm").limit(10).to_a
    # List DMs separately (only channels with a resolvable "other user")
    dm_channels = current_user.channels
                              .where(channel_type: "dm")
                              .includes(members: :avatar_attachment)
                              .limit(20)
                              .to_a

    @sidebar_dm_other_users_by_channel_id = {}
    @sidebar_dm_channels = dm_channels.select do |channel|
      other_user = channel.members.find { |member| member.id != current_user.id }
      next false unless other_user

      @sidebar_dm_other_users_by_channel_id[channel.id] = other_user
      true
    end
    @sidebar_dm_names_by_channel_id = @sidebar_dm_other_users_by_channel_id.transform_values { |user| user&.username }

    # Calculate unread counts for sidebar channels
    @sidebar_unread_counts = calculate_unread_counts
  end

  def calculate_unread_counts
    all_channels = @sidebar_my_channels + @sidebar_dm_channels
    return {} if all_channels.empty?

    current_user.channel_memberships
                .where(channel_id: all_channels.map(&:id))
                .joins("INNER JOIN channels ON channels.id = channel_memberships.channel_id")
                .joins("INNER JOIN messages ON messages.channel_id = channel_memberships.channel_id")
                .where.not(messages: { user_id: current_user.id })
                .where("messages.created_at > COALESCE(channel_memberships.last_read_at, channel_memberships.joined_at, channels.created_at)")
                .group("channel_memberships.channel_id")
                .count("messages.id")
  end

  def mark_active
    # Touch user to indicate recent activity for simple presence tracking
    return unless current_user

    activity_window = 1.minute
    return if current_user.updated_at && current_user.updated_at >= activity_window.ago + 1.second

    current_user.touch
  rescue ActiveRecord::ActiveRecordError => e
    Rails.logger.debug "Failed to touch user for activity tracking: #{e.class}"
  end

  def set_user_timezone(&block)
    timezone = current_user&.timezone.presence || "UTC"
    Time.use_zone(timezone, &block)
  end

  def require_admin
    unless logged_in?
      redirect_to signin_path, alert: "Please sign in to continue"
      return
    end

    unless current_user.admin?
      redirect_to dashboard_path, alert: "Admins only."
    end
  end

  def check_session_timeout
    session_timeout = 8.hours.to_i
    now = Time.current.to_i
    last_activity = last_session_activity_epoch

    if last_activity && (now - last_activity) > session_timeout
      reset_session
      redirect_to signin_path, alert: "Your session has expired. Please sign in again."
    else
      session[:last_activity_at] = now
      session.delete(:last_activity_time)
    end
  rescue StandardError => e
    Rails.logger.warn "Session timeout check failed: #{e.class}"
    session[:last_activity_at] = Time.current.to_i
    session.delete(:last_activity_time)
  end

  def last_session_activity_epoch
    raw_epoch = session[:last_activity_at]
    return raw_epoch.to_i if raw_epoch.present? && raw_epoch.to_s.match?(/\A\d+\z/)

    legacy_time = session[:last_activity_time]
    return nil if legacy_time.blank?

    Time.zone.parse(legacy_time.to_s)&.to_i
  rescue ArgumentError, TypeError
    nil
  end

  def home_assistant_addon?
    ENV["HOME_ASSISTANT_ADDON"] == "true"
  end

  def home_assistant_verified?
    return false unless home_assistant_addon?

    # In HA addon mode, verify the request comes from a trusted origin/IP
    # and carries a valid session nonce (M6).
    verify_home_assistant_origin && verify_ha_ingress_nonce
  end

  def verify_home_assistant_origin
    return true unless home_assistant_addon?

    # Allow requests from Home Assistant ingress or local network
    origin = request.headers["Origin"] || request.headers["Referer"]

    # Allow if no origin (direct access or HA ingress strips it)
    return true if origin.blank?

    # Parse origin and check if it's from expected sources
    begin
      uri = URI.parse(origin)
      # Allow localhost, local IPs, or homeassistant.local
      allowed = uri.host.match?(/^(localhost|127\.0\.0\.1|192\.168\.\d+\.\d+|10\.\d+\.\d+\.\d+|homeassistant\.local)$/i)

      unless allowed
        Rails.logger.warn "Rejected request from unauthorized origin"
        head :forbidden
        return false
      end

      true
    rescue URI::InvalidURIError => e
      Rails.logger.warn "Invalid origin URI: #{e.class}"
      head :forbidden
      false
    end
  end

  # M6: Lightweight session nonce for HA Ingress CSRF protection.
  # Generates a per-session nonce on first page load; AJAX requests must echo it back
  # via the X-HA-Nonce header.  Only validated for non-GET state-changing requests.
  def ha_ingress_nonce
    session[:ha_ingress_nonce] ||= SecureRandom.hex(16)
  end
  helper_method :ha_ingress_nonce

  def verify_ha_ingress_nonce
    return true unless home_assistant_addon?
    # Only validate on state-changing requests; GET/HEAD are safe by HTTP spec.
    return true unless request.post? || request.patch? || request.put? || request.delete?
    # Skip for API endpoints that use token auth (they have their own CSRF protection)
    return true if request.path.start_with?("/api/")

    provided = request.headers["X-HA-Nonce"]
    stored   = session[:ha_ingress_nonce]

    if stored.blank? || provided.blank? || !ActiveSupport::SecurityUtils.secure_compare(stored, provided)
      Rails.logger.warn "HA ingress nonce mismatch"
      head :forbidden
      return false
    end

    true
  end

  # Handle CSRF token validation
  def handle_unverified_request
    Rails.logger.warn "CSRF token verification failed"
    super
  end
end
