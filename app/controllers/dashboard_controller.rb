class DashboardController < ApplicationController
  before_action :require_login
  
  def index
    @public_channels = Channel.public_channels.includes(:created_by).limit(10)
    @my_channels = current_user.channels.includes(:created_by).limit(10)
    @recent_messages = Message.includes(:user, :channel)
                              .joins(:channel)
                              .where(channels: { id: Channel.accessible_by(current_user) })
                              .recent
                              .limit(5)
  end
end
