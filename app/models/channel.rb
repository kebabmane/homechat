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
  scope :accessible_by, ->(user) { where(id: user.channels.select(:id)).or(public_channels) }
  
  def public?
    channel_type == 'public'
  end
  
  def private?
    channel_type == 'private'
  end

  def dm?
    channel_type == 'dm'
  end
  
  
  def add_member(user)
    return false if members.include?(user)
    channel_memberships.create(user: user)
  end
  
  def remove_member(user)
    channel_memberships.find_by(user: user)&.destroy
  end
  
  def member_count
    channel_memberships.count
  end

  def online_members_count(window: 5.minutes)
    members.where('users.updated_at > ?', Time.current - window).count
  end
end
