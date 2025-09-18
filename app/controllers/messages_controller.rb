class MessagesController < ApplicationController
  before_action :require_login
  before_action :set_channel
  before_action :verify_channel_access

  def create
    # Ensure user is a member of the channel (auto-join for public channels)
    unless current_user.member_of?(@channel)
      if @channel.public?
        @channel.add_member(current_user)
      else
        redirect_to channels_path, alert: 'You must be a member of this private channel to send messages.'
        return
      end
    end

    begin
      @message = @channel.messages.build(message_params)
      @message.user = current_user

      if @message.save
        redirect_to @channel, notice: 'Message sent successfully.'
      else
        # Redirect for validation failures with alert
        redirect_to @channel, alert: "Message could not be sent: #{@message.errors.full_messages.join(', ')}"
      end
    rescue ActionController::ParameterMissing
      redirect_to @channel, alert: 'Message content is required.'
    end
  end

  private

  def set_channel
    @channel = Channel.find(params[:channel_id])
  end

  def verify_channel_access
    unless @channel.public? || current_user.member_of?(@channel)
      redirect_to channels_path, alert: 'You do not have access to this channel.'
    end
  end

  def message_params
    params.require(:message).permit(:content, :rich_content, files: [])
  end
end
