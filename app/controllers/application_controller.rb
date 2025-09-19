class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Configure CSRF protection for Home Assistant add-on environment
  if ENV['HOME_ASSISTANT_ADDON'] == 'true'
    protect_from_forgery with: :null_session, if: ->(request) { request.format.json? }
    protect_from_forgery with: :exception, unless: ->(request) { request.format.json? }

    # Skip CSRF protection for specific endpoints if needed
    # skip_before_action :verify_authenticity_token, only: [:some_api_endpoint]
  else
    protect_from_forgery with: :exception
  end
  
  layout :determine_layout
  before_action :set_sidebar_data, if: :logged_in?
  before_action :mark_active, if: :logged_in?
  before_action :check_session_timeout, if: :logged_in?
  
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
    @sidebar_public_channels = Channel.public_channels.includes(:creator).limit(10)
    # Show only non-DM channels in the Channels section
    @sidebar_my_channels = current_user.channels.where.not(channel_type: 'dm').includes(:creator).limit(10)
    # List DMs separately
    @sidebar_dm_channels = current_user.channels.where(channel_type: 'dm').includes(:creator).limit(20)
  end

  def mark_active
    # Touch user to indicate recent activity for simple presence tracking
    current_user.touch
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

  # Handle CSRF token validation for Home Assistant ingress environment
  def handle_unverified_request
    if ENV['HOME_ASSISTANT_ADDON'] == 'true'
      Rails.logger.warn "CSRF token verification failed in Home Assistant add-on environment"

      # For form submissions in HA add-on, try to gracefully handle the error
      if request.format.html? && request.post?
        Rails.logger.warn "Form submission CSRF failure - X-Ingress-Path: #{request.headers['X-Ingress-Path']}"
        redirect_back(fallback_location: root_path, alert: 'Security verification failed. Please try again.')
        return
      end
    end

    super
  end
end
