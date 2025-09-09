class Api::V1::ChannelsController < Api::V1::BaseController
  # GET /api/v1/channels
  def index
    user = current_api_user
    channels = Channel.accessible_by(user).order(:name)
    render json: {
      channels: channels.map { |c| { id: c.id, name: c.name, type: c.channel_type, members: c.member_count } }
    }
  end
end

