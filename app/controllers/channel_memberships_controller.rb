class ChannelMembershipsController < ApplicationController
  before_action :require_login
  before_action :set_channel

  def index
    authorize! :read, @channel
    respond_to do |format|
      format.html { render partial: 'channel_memberships/list', locals: { channel: @channel } }
      format.turbo_stream { render partial: 'channel_memberships/list', locals: { channel: @channel } }
    end
  end

  private

  def set_channel
    @channel = Channel.find(params[:channel_id])
  end

  def authorize!(_action, resource)
    unless resource.members.exists?(id: current_user.id)
      head :forbidden
    end
  end
end
