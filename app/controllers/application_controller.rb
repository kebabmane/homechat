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
    @current_user ||= User.find(session[:user_id]) if session[:user_id]
  end
  
  def logged_in?
    !!current_user
  end
  
  def require_login
    unless logged_in?
      redirect_to signin_path, alert: 'Please sign in to continue'
    end
  end
  
  def determine_layout
    logged_in? ? 'application' : 'authentication'
  end
  
  def set_sidebar_data
    @sidebar_public_channels = Channel.public_channels.limit(10)
    # Show only non-DM channels in the Channels section
    @sidebar_my_channels = current_user.channels.where.not(channel_type: 'dm').limit(10)
    # List DMs separately
    @sidebar_dm_channels = current_user.channels.where(channel_type: 'dm').limit(20)

    # Calculate unread counts for sidebar channels
    @sidebar_unread_counts = calculate_unread_counts
  end

  def calculate_unread_counts
    return {} unless session[:last_read].present?

    counts = {}
    all_channels = @sidebar_my_channels + @sidebar_dm_channels

    all_channels.each do |channel|
      last_read_str = session[:last_read][channel.id.to_s]
      next unless last_read_str

      begin
        last_read_at = Time.parse(last_read_str)
        count = channel.unread_count(since: last_read_at)
        counts[channel.id] = count if count > 0
      rescue ArgumentError
        # Invalid time format, skip
      end
    end

    counts
  end

  def mark_active
    # Touch user to indicate recent activity for simple presence tracking
    return unless current_user

    activity_window = 1.minute
    return if current_user.updated_at && current_user.updated_at >= activity_window.ago

    current_user.touch
  rescue ActiveRecord::ActiveRecordError => e
    Rails.logger.debug "Failed to touch user for activity tracking: #{e.class} #{e.message}"
  end

  def set_user_timezone(&block)
    timezone = current_user&.timezone.presence || 'UTC'
    Time.use_zone(timezone, &block)
  end

  def require_admin
    unless logged_in?
      redirect_to signin_path, alert: 'Please sign in to continue'
      return
    end

    unless current_user.admin?
      redirect_to dashboard_path, alert: 'Admins only.'
    end
  end

  def check_session_timeout
    session_timeout = 8.hours
    last_activity = session[:last_activity_time]

    if last_activity && Time.current > Time.parse(last_activity) + session_timeout
      reset_session
      redirect_to signin_path, alert: 'Your session has expired. Please sign in again.'
    else
      session[:last_activity_time] = Time.current.to_s
    end
  rescue StandardError => e
    Rails.logger.warn "Session timeout check failed: #{e.message}"
    session[:last_activity_time] = Time.current.to_s
  end

  def home_assistant_addon?
    ENV['HOME_ASSISTANT_ADDON'] == 'true'
  end

  def home_assistant_verified?
    return false unless home_assistant_addon?

    # In HA addon mode, verify the request comes from the ingress proxy
    # HA ingress adds X-Ingress-Path header
    request.headers['X-Ingress-Path'].present? || verify_home_assistant_origin
  end

  def verify_home_assistant_origin
    return true unless home_assistant_addon?

    # Allow requests from Home Assistant ingress or local network
    origin = request.headers['Origin'] || request.headers['Referer']

    # Allow if no origin (direct access or HA ingress strips it)
    return true if origin.blank?

    # Parse origin and check if it's from expected sources
    begin
      uri = URI.parse(origin)
      # Allow localhost, local IPs, or homeassistant.local
      allowed = uri.host.match?(/^(localhost|127\.0\.0\.1|192\.168\.\d+\.\d+|10\.\d+\.\d+\.\d+|homeassistant\.local)$/i)

      unless allowed
        Rails.logger.warn "Rejected request from unauthorized origin: #{origin}"
        head :forbidden
        return false
      end

      true
    rescue URI::InvalidURIError => e
      Rails.logger.warn "Invalid origin URI: #{origin} - #{e.message}"
      head :forbidden
      false
    end
  end

  # Handle CSRF token validation
  def handle_unverified_request
    Rails.logger.warn "CSRF token verification failed for #{request.path} from #{request.remote_ip}"
    super
  end
end
