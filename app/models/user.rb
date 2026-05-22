class User < ApplicationRecord
  include AccountLockable
  include TwoFactorAuthenticatable

  PRESENCE_STALE_WINDOW = 30.seconds

  has_secure_password
  has_one_attached :avatar

  validates :username, presence: true, uniqueness: true, length: { minimum: 3, maximum: 50 }
  validates :password, length: { minimum: 8 }, if: -> { password.present? }
  validates :role, inclusion: { in: %w[user admin] }
  validates :timezone, inclusion: { in: ActiveSupport::TimeZone.all.map(&:name) }, allow_blank: true

  # Avatar validations
  validate :avatar_validation

  # Approval scopes
  scope :pending_approval, -> { where(approved: false) }
  scope :approved, -> { where(approved: true) }

  # Associations
  has_many :messages, dependent: :destroy
  has_many :created_channels, class_name: "Channel", foreign_key: "created_by_id", dependent: :destroy
  has_many :channel_memberships, dependent: :destroy
  has_many :channels, through: :channel_memberships
  has_many :api_tokens, dependent: :destroy
  has_many :user_e2ee_keys, dependent: :destroy

  # Callbacks
  after_create :join_default_channels

  def admin?
    role == "admin"
  end

  def user?
    role == "user"
  end

  # Approval methods
  def pending_approval?
    !approved? && Setting.fetch(:require_signup_approval, false)
  end

  def approve!(admin_user)
    update!(
      approved: true,
      approved_at: Time.current,
      approved_by_id: admin_user.id
    )

    AuditLog.log(
      action: "user.approved",
      user: admin_user,
      resource: self,
      metadata: { approved_by: admin_user.username }
    )
  end

  def reject!
    # Delete the user entirely when rejected
    destroy!
  end

  def approved_by
    User.find_by(id: approved_by_id) if approved_by_id
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
    timestamp = Time.current
    return if online? && last_seen_at && last_seen_at >= timestamp - PRESENCE_STALE_WINDOW

    update!(is_online: true, last_seen_at: timestamp)
    broadcast_presence_change
  end

  def mark_offline!
    timestamp = Time.current

    changes = {}
    changes[:is_online] = false if online?
    changes[:last_seen_at] = timestamp if last_seen_at.nil? || last_seen_at < timestamp - PRESENCE_STALE_WINDOW

    return if changes.empty?

    update!(changes)
    broadcast_presence_change
  end

  def update_presence!
    timestamp = Time.current

    changes = {}
    changes[:last_seen_at] = timestamp if last_seen_at.nil? || last_seen_at < timestamp - PRESENCE_STALE_WINDOW
    changes[:is_online] = true unless online?

    return if changes.empty?

    update!(changes)
    broadcast_presence_change
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
    username&.first&.upcase || "?"
  end

  def avatar_color_index
    username&.hash&.abs&.% 8 || 0
  end

  # Password reset methods
  def generate_password_reset_token!
    selector = SecureRandom.hex(10)
    verifier = SecureRandom.urlsafe_base64(32)
    raw_token = "#{selector}.#{verifier}"
    update!(
      password_reset_token_selector: selector,
      password_reset_token_digest: BCrypt::Password.create(verifier),
      password_reset_sent_at: Time.current
    )
    raw_token
  end

  def password_reset_token_valid?(token)
    return false if password_reset_token_digest.nil? || password_reset_token_selector.nil?
    return false if password_reset_sent_at.nil? || password_reset_sent_at < 24.hours.ago
    selector, verifier = token.to_s.split(".", 2)
    return false if selector.blank? || verifier.blank?
    return false unless selector == password_reset_token_selector

    BCrypt::Password.new(password_reset_token_digest).is_password?(verifier)
  end

  def clear_password_reset_token!
    update!(
      password_reset_token_selector: nil,
      password_reset_token_digest: nil,
      password_reset_sent_at: nil
    )
  end

  def password_reset_pending?
    password_reset_token_selector.present? &&
      password_reset_token_digest.present? &&
      password_reset_sent_at.present? &&
      password_reset_sent_at >= 24.hours.ago
  end

  private

  def avatar_validation
    return unless avatar.attached?

    # File size validation (5MB limit)
    if avatar.blob.byte_size > 5.megabytes
      errors.add(:avatar, "must be less than 5MB")
    end

    # Content type validation
    acceptable_types = %w[image/jpeg image/jpg image/png image/gif image/webp]
    unless acceptable_types.include?(avatar.blob.content_type)
      errors.add(:avatar, "must be a JPEG, PNG, GIF, or WebP image")
    end
  end

  def broadcast_presence_change
    ActionCable.server.broadcast("presence", {
      type: "presence_update",
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
    home_channel = Channel.find_by(name: "home", channel_type: "public")
    unless home_channel
      home_channel = Channel.create!(
        name: "home",
        description: "Default home channel for all users",
        channel_type: "public",
        created_by: self
      )
      Rails.logger.info "Default home channel created by first user_id=#{id}"
    end

    # Join the home channel if not already a member
    if home_channel && !member_of?(home_channel)
      home_channel.add_member(self)
    end
  end
end
