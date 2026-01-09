class Channel < ApplicationRecord
  belongs_to :created_by, class_name: 'User'
  belongs_to :creator, class_name: 'User', foreign_key: 'created_by_id'
  
  validates :name, presence: true, uniqueness: true, length: { minimum: 2, maximum: 50 }
  validates :channel_type, inclusion: { in: %w[public private dm] }
  validates :description, length: { maximum: 500 }
  
  # Associations
  has_many :messages, dependent: :destroy
  has_many :channel_memberships, dependent: :destroy
  has_many :members, through: :channel_memberships, source: :user
  
  scope :public_channels, -> { where(channel_type: 'public') }
  scope :private_channels, -> { where(channel_type: 'private') }
  scope :dm_channels, -> { where(channel_type: 'dm') }
  scope :accessible_by, lambda { |user|
    next public_channels if user.nil?

    left_outer_joins(:channel_memberships)
      .where('channels.channel_type = :public OR channel_memberships.user_id = :user_id',
             public: 'public', user_id: user.id)
      .distinct
  }

  def accessible_by?(user)
    return true if public?
    return true if member?(user)
    false
  end
  
  def public?
    channel_type == 'public'
  end
  
  def private?
    channel_type == 'private'
  end

  def dm?
    channel_type == 'dm'
  end

  # For DM channels, get the other participant (not the current user)
  def other_user(current_user)
    return nil unless dm?
    members.where.not(id: current_user.id).first
  end
  
  
  def add_member(user)
    return false if member?(user)
    channel_memberships.create(user: user)
  end
  
  def remove_member(user)
    channel_memberships.find_by(user: user)&.destroy
  end
  
  def member_count
    # Use counter cache if column exists, otherwise count directly
    if has_attribute?(:memberships_count) && memberships_count.present?
      memberships_count
    else
      channel_memberships.count
    end
  end

  def online_members_count(window: 5.minutes)
    members.where('users.updated_at > ?', Time.current - window).count
  end

  def member?(user)
    return false unless user

    channel_memberships.exists?(user_id: user.id)
  end

  # Count messages since a given timestamp (for unread indicators)
  def unread_count(since:)
    return 0 unless since

    messages.where('created_at > ?', since).count
  end
end
