class ChannelsController < ApplicationController
  before_action :require_login
  before_action :set_channel, only: [ :show, :join, :leave, :edit, :update, :destroy ]
  before_action :set_channel_for_member_actions, only: [ :invite ]

  def index
    @public_channels = Channel.where(channel_type: "public").includes(:creator)
    # Show only channels (public/private) you belong to; exclude DMs from this list
    @my_channels = current_user.channels.where.not(channel_type: "dm").includes(:creator)

    public_channel_ids = @public_channels.map(&:id)
    my_channel_ids = @my_channels.map(&:id)
    visible_channel_ids = (public_channel_ids + my_channel_ids).uniq

    @channel_member_counts = if visible_channel_ids.any?
      ChannelMembership.where(channel_id: visible_channel_ids).group(:channel_id).count
    else
      {}
    end

    @joined_public_channel_ids = if public_channel_ids.any?
      current_user.channel_memberships.where(channel_id: public_channel_ids).pluck(:channel_id).index_with { |id| true }
    else
      {}
    end

    @my_memberships_by_channel_id = if my_channel_ids.any?
      current_user.channel_memberships.where(channel_id: my_channel_ids).index_by(&:channel_id)
    else
      {}
    end
  end

  def show
    unless @channel.public? || current_user.member_of?(@channel)
      redirect_to channels_path, alert: "You do not have access to this channel."
      return
    end

    @messages = @channel.messages
      .includes(:files_attachments, user: :avatar_attachment)
      .recent
      .limit(50)
    @has_unencrypted_visible_messages = E2eePolicy.required_for_channel?(@channel) &&
      @messages.any? { |message| !message.e2ee? }
    # Unread divider: track last-read per channel membership
    membership = @channel.channel_memberships.find_by(user: current_user)
    @last_read_at = membership&.last_read_at
    if membership && (@last_read_at.nil? || @last_read_at < 30.seconds.ago)
      membership.update_columns(last_read_at: Time.current)
    end
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
      redirect_to @channel, notice: "Channel was successfully created."
    else
      render :new
    end
  end

  def edit
    unless can_manage_channel?(@channel)
      redirect_to @channel, alert: "You do not have permission to edit this channel."
    end
  end

  def update
    unless can_manage_channel?(@channel)
      redirect_to @channel, alert: "You do not have permission to edit this channel."
      return
    end

    if @channel.update(channel_params)
      redirect_to @channel, notice: "Channel was successfully updated."
    else
      render :edit
    end
  end

  def destroy
    unless can_manage_channel?(@channel)
      redirect_to channels_path, alert: "You do not have permission to delete this channel."
      return
    end

    @channel.destroy
    redirect_to channels_path, notice: "Channel was successfully deleted."
  end

  def join
    unless @channel.public?
      redirect_to channels_path, alert: "You cannot join this channel."
      return
    end

    if current_user.member_of?(@channel)
      redirect_to @channel, notice: "You are already a member of this channel."
    else
      @channel.add_member(current_user)
      redirect_to @channel, notice: "Successfully joined the channel!"
    end
  end

  def leave
    if current_user.member_of?(@channel)
      if @channel.dm?
        redirect_to @channel, alert: "Direct messages cannot be left."
        return
      end

      @channel.remove_member(current_user)
      redirect_to channels_path, notice: "You have left the channel."
    else
      redirect_to channels_path, alert: "You are not a member of this channel."
    end
  end

  def invite
    unless can_manage_channel?(@channel) && @channel.private?
      redirect_to @channel, alert: "Only the channel owner or an admin can invite to a private channel."
      return
    end

    username = params[:username].to_s.strip
    user = User.find_by(username: username)
    if user.nil?
      redirect_to edit_channel_path(@channel), alert: "User not found." and return
    end

    if @channel.member?(user)
      redirect_to @channel, notice: "User is already a member." and return
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
