class DmsController < ApplicationController
  before_action :require_login

  def new
  end

  def create
    username = params[:username].to_s.strip
    target = User.find_by(username: username)
    if target.nil? || target == current_user
      redirect_to new_dm_path, alert: 'Invalid user' and return
    end

    channel = find_or_create_dm(current_user, target)
    redirect_to channel
  end

  private

  def find_or_create_dm(a, b)
    # Ensure consistent ordering for name
    users = [a, b].sort_by(&:id)
    name = "dm-#{users.first.username}-#{users.last.username}"
    channel = Channel.dm_channels.joins(:channel_memberships)
                  .where(name: name).first
    return channel if channel

    channel = Channel.create!(name: name, channel_type: 'dm', created_by: a)
    channel.add_member(a)
    channel.add_member(b)
    channel
  end
end

