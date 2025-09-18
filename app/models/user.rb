class User < ApplicationRecord
  has_secure_password
  has_one_attached :avatar

  validates :username, presence: true, uniqueness: true, length: { minimum: 3, maximum: 50 }
  validates :role, inclusion: { in: %w[user admin] }

  # Avatar validations
  validate :avatar_validation

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

  # Presence methods
  def online?
    is_online == true
  end

  def offline?
    !online?
  end

  def mark_online!
    update!(is_online: true, last_seen_at: Time.current)
    broadcast_presence_change
  end

  def mark_offline!
    update!(is_online: false, last_seen_at: Time.current)
    broadcast_presence_change
  end

  def update_presence!
    update!(last_seen_at: Time.current)
    mark_online! unless online?
  end

  def set_status!(new_status)
    update!(status: new_status)
    broadcast_presence_change
  end

  def recently_seen?(within: 5.minutes)
    last_seen_at && last_seen_at > within.ago
  end

  def avatar_url
    if avatar.attached?
      Rails.application.routes.url_helpers.rails_blob_url(avatar, only_path: false)
    else
      nil
    end
  end

  def avatar_initials
    username&.first&.upcase || '?'
  end

  def avatar_color_index
    username&.hash&.abs&.% 8 || 0
  end

  private

  def avatar_validation
    return unless avatar.attached?

    # File size validation (5MB limit)
    if avatar.blob.byte_size > 5.megabytes
      errors.add(:avatar, 'must be less than 5MB')
    end

    # Content type validation
    acceptable_types = %w[image/jpeg image/jpg image/png image/gif image/webp]
    unless acceptable_types.include?(avatar.blob.content_type)
      errors.add(:avatar, 'must be a JPEG, PNG, GIF, or WebP image')
    end
  end

  def broadcast_presence_change
    ActionCable.server.broadcast("presence", {
      type: 'presence_update',
      user: {
        id: id,
        username: username,
        is_online: online?,
        status: status,
        last_seen_at: last_seen_at&.iso8601
      }
    })
  end

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
