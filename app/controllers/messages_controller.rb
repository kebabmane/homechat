class MessagesController < ApplicationController
  before_action :require_login
  before_action :set_channel
  before_action :verify_channel_access
  before_action :set_message, only: [ :edit, :update ]
  before_action :verify_message_author, only: [ :edit, :update ]

  def create
    # Ensure user is a member of the channel (auto-join for public channels)
    unless current_user.member_of?(@channel)
      if @channel.public?
        @channel.add_member(current_user)
      else
        redirect_to channels_path, alert: "You must be a member of this private channel to send messages."
        return
      end
    end

    begin
      payload = message_params.to_h.with_indifferent_access
      if (error = E2eePolicy.validate_enforced_write(channel: @channel, payload:, request:, allow_files: false))
        respond_to do |format|
          format.html { redirect_to @channel, alert: error[:message], status: error[:status] }
          format.json { render json: { success: false, error: error[:message], code: error[:code] }, status: error[:status] }
        end
        return
      end

      @message = @channel.messages.build(message_params)
      @message.user = current_user

      if @message.save
        redirect_to @channel
      else
        # Redirect for validation failures with alert
        redirect_to @channel, alert: "Message could not be sent: #{@message.errors.full_messages.join(', ')}"
      end
    rescue ActionController::ParameterMissing
      redirect_to @channel, alert: "Message content is required."
    end
  end

  def edit
  end

  def update
    if @message.e2ee?
      redirect_to @channel, alert: "Encrypted messages cannot be edited."
      return
    end

    if @message.update(message_params.slice(:content))
      redirect_to @channel
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_channel
    @channel = Channel.find(params[:channel_id])
  end

  def verify_channel_access
    unless @channel.public? || current_user.member_of?(@channel)
      redirect_to channels_path, alert: "You do not have access to this channel."
    end
  end

  def set_message
    @message = @channel.messages.find(params[:id])
  end

  def verify_message_author
    unless @message.user == current_user
      redirect_to @channel, alert: "You can only edit your own messages."
    end
  end

  def message_params
    params.require(:message).permit(
      :content,
      :rich_content,
      :content_encoding,
      :encrypted_content,
      :content_hmac,
      :sender_key_fingerprint,
      :sender_device_id,
      :e2ee_version,
      files: []
    )
  end
end
