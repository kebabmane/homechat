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

  # Callbacks
  after_create :join_default_channels
  
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

  private

  def join_default_channels
    # Create home channel if it doesn't exist and this is the first user
    home_channel = Channel.find_by(name: 'home', channel_type: 'public')
    unless home_channel
      home_channel = Channel.create!(
        name: 'home',
        description: 'Default home channel for all users',
        channel_type: 'public',
        created_by: self
      )
      Rails.logger.info "✅ Default 'home' channel created by first user: #{username}"
    end

    # Join the home channel if not already a member
    if home_channel && !member_of?(home_channel)
      home_channel.add_member(self)
    end
  end
end
