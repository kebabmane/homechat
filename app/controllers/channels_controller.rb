class ChannelsController < ApplicationController
  before_action :require_login
  before_action :set_channel, only: [:show, :join, :leave, :edit, :update, :destroy]
  before_action :set_channel_for_member_actions, only: [:invite]

  def index
    @public_channels = Channel.where(channel_type: 'public').includes(:creator, :channel_memberships)
    # Show only channels (public/private) you belong to; exclude DMs from this list
    @my_channels = current_user.channels.where.not(channel_type: 'dm').includes(:creator, :channel_memberships)
  end

  def show
    unless @channel.public? || current_user.member_of?(@channel)
      redirect_to channels_path, alert: 'You do not have access to this channel.'
      return
    end
    
    @messages = @channel.messages.includes(:user).recent.limit(50)
    # Unread divider: track last-read per channel in session
    session[:last_read] ||= {}
    @last_read_at = session[:last_read][@channel.id.to_s] && Time.parse(session[:last_read][@channel.id.to_s]) rescue nil
    session[:last_read][@channel.id.to_s] = Time.current.iso8601
    @message = Message.new
  end

  def new
    @channel = Channel.new
  end

  def create
    @channel = Channel.new(channel_params)
    @channel.created_by = current_user

    if @channel.save
      @channel.add_member(current_user)
      redirect_to @channel, notice: 'Channel was successfully created.'
    else
      render :new
    end
  end

  def edit
    unless can_manage_channel?(@channel)
      redirect_to @channel, alert: 'You do not have permission to edit this channel.'
    end
  end

  def update
    unless can_manage_channel?(@channel)
      redirect_to @channel, alert: 'You do not have permission to edit this channel.'
      return
    end

    if @channel.update(channel_params)
      redirect_to @channel, notice: 'Channel was successfully updated.'
    else
      render :edit
    end
  end

  def destroy
    unless can_manage_channel?(@channel)
      redirect_to channels_path, alert: 'You do not have permission to delete this channel.'
      return
    end

    @channel.destroy
    redirect_to channels_path, notice: 'Channel was successfully deleted.'
  end

  def join
    unless @channel.public?
      redirect_to channels_path, alert: 'You cannot join this channel.'
      return
    end

    if current_user.member_of?(@channel)
      redirect_to @channel, notice: 'You are already a member of this channel.'
    else
      @channel.add_member(current_user)
      redirect_to @channel, notice: 'Successfully joined the channel!'
    end
  end

  def leave
    if current_user.member_of?(@channel)
      @channel.remove_member(current_user)
      redirect_to channels_path, notice: 'You have left the channel.'
    else
      redirect_to channels_path, alert: 'You are not a member of this channel.'
    end
  end

  def invite
    unless can_manage_channel?(@channel) && @channel.private?
      redirect_to @channel, alert: 'Only the channel owner or an admin can invite to a private channel.'
      return
    end

    username = params[:username].to_s.strip
    user = User.find_by(username: username)
    if user.nil?
      redirect_to edit_channel_path(@channel), alert: 'User not found.' and return
    end

    if @channel.members.include?(user)
      redirect_to @channel, notice: 'User is already a member.' and return
    end

    @channel.add_member(user)
    redirect_to @channel, notice: "Invited #{user.username} to the channel."
  end

  private

  def set_channel
    @channel = Channel.find(params[:id])
  end

  def channel_params
    params.require(:channel).permit(:name, :description, :channel_type)
  end

  def can_manage_channel?(channel)
    current_user.admin? || channel.creator == current_user
  end

  def set_channel_for_member_actions
    @channel = Channel.find(params[:id])
  end
end
