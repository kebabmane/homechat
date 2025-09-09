class User < ApplicationRecord
  has_secure_password
  has_one_attached :avatar
  
  validates :username, presence: true, uniqueness: true, length: { minimum: 3, maximum: 50 }
  validates :role, inclusion: { in: %w[user admin] }
  
  # Associations
  has_many :messages, dependent: :destroy
  has_many :created_channels, class_name: 'Channel', foreign_key: 'created_by_id', dependent: :destroy
  has_many :channel_memberships, dependent: :destroy
  has_many :channels, through: :channel_memberships
  
  def admin?
    role == 'admin'
  end
  
  def user?
    role == 'user'
  end
  
  def member_of?(channel)
    channel_memberships.exists?(channel: channel)
  end
  
  def can_access_channel?(channel)
    return true if channel.public?
    return true if channel.created_by == self
    member_of?(channel)
  end
end
