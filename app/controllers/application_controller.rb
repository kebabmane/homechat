class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  
  layout :determine_layout
  before_action :set_sidebar_data, if: :logged_in?
  before_action :mark_active, if: :logged_in?
  
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
    unless logged_in? && current_user.admin?
      redirect_to dashboard_path, alert: 'Admins only.'
    end
  end
end
