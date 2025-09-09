class ChannelMembership < ApplicationRecord
  belongs_to :user
  belongs_to :channel
  
  validates :user_id, uniqueness: { scope: :channel_id }
  
  scope :for_user, ->(user) { where(user: user) }
  scope :for_channel, ->(channel) { where(channel: channel) }
  
  before_create :set_joined_at

  after_commit :broadcast_member_count, on: [:create, :destroy]
  
  private
  
  def set_joined_at
    self.joined_at ||= Time.current
  end

  def broadcast_member_count
    channel.broadcast_replace_to channel,
      target: ActionView::RecordIdentifier.dom_id(channel, :member_count),
      html: channel.member_count.to_s
  end
end
