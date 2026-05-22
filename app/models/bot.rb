class Bot < ApplicationRecord
  BOT_TYPES = %w[webhook api ai].freeze

  # Encrypt webhook secrets at rest
  encrypts :webhook_secret

  belongs_to :identity_user, class_name: "User", optional: true
  delegate :messages, to: :identity_user, allow_nil: true

  validates :name, presence: true, uniqueness: true
  validates :bot_type, presence: true, inclusion: { in: BOT_TYPES }
  validates :webhook_id, presence: true, if: -> { bot_type == "webhook" }
  validates :webhook_id, uniqueness: true, allow_blank: true
  validates :webhook_secret, presence: true, if: -> { bot_type == "webhook" }
  validates :instructions, presence: true, if: :ai_bot?
  validates :model, presence: true, if: :ai_bot?
  validates :name, format: { with: /\A[a-zA-Z0-9_]{3,50}\z/, message: "must be 3-50 characters and only letters, numbers, and underscores" }, if: :ai_bot?
  validate :identity_username_available, if: :ai_bot?

  HUMAN_ATTRIBUTE_NAMES = { name: "Bot handle", instructions: "System prompt" }.freeze

  def self.human_attribute_name(attr, options = {})
    HUMAN_ATTRIBUTE_NAMES[attr.to_sym] || super
  end

  scope :active, -> { where(active: true) }
  scope :webhooks, -> { where(bot_type: "webhook") }
  scope :api_bots, -> { where(bot_type: "api") }
  scope :ai_bots, -> { where(bot_type: "ai") }

  before_validation :set_defaults
  before_save :ensure_identity_user

  def webhook_url(base_url)
    return nil if webhook_id.blank?
    "#{base_url}/api/v1/webhooks/#{webhook_id}"
  end

  def deactivate!
    transaction do
      update!(active: false)
      identity_user&.mark_offline!
    end
  end

  def activate!
    transaction do
      update!(active: true)
      ensure_identity_user
      identity_user&.mark_online!
    end
  end

  def webhook?
    bot_type == "webhook"
  end

  def api_bot?
    bot_type == "api"
  end

  def ai_bot?
    bot_type == "ai"
  end

  def effective_model
    model.presence || Setting.fetch("litellm_default_model", nil)
  end

  def regenerate_webhook_secret!
    return unless webhook?
    self.webhook_secret = SecureRandom.hex(32)
    save!
  end

  def verify_webhook_signature(payload, signature_header)
    return false unless webhook? && webhook_secret.present?
    return false if signature_header.blank?

    # Check that header starts with "sha256=" and extract signature
    return false unless signature_header.to_s.start_with?("sha256=")

    signature = signature_header.to_s.sub(/^sha256=/, "")
    return false if signature.blank?

    # Calculate expected signature
    expected_signature = OpenSSL::HMAC.hexdigest("SHA256", webhook_secret, payload)

    # Secure comparison to prevent timing attacks
    ActiveSupport::SecurityUtils.secure_compare(signature, expected_signature)
  end

  private

  def set_defaults
    self.active = true if active.nil?
    self.bot_type = "webhook" if bot_type.blank?
    self.webhook_id = SecureRandom.uuid if webhook? && webhook_id.blank?
    self.webhook_secret = SecureRandom.hex(32) if webhook? && webhook_secret.blank?
    apply_ai_defaults if ai_bot?
  end

  def apply_ai_defaults
    self.model = Setting.fetch("litellm_default_model", nil) if model.blank?
  end

  def ensure_identity_user
    return unless ai_bot?

    username = name.to_s

    if identity_user.present?
      identity_user.update!(username: username) if identity_user.username != username
      ensure_identity_presence(identity_user)
      return identity_user
    end

    if (existing_user = User.find_by(username: username))
      self.identity_user = existing_user
      ensure_identity_presence(existing_user)
      return existing_user
    end

    password = SecureRandom.hex(32)
    self.identity_user = User.create!(
      username: username,
      password: password,
      password_confirmation: password,
      role: "user"
    )
    ensure_identity_presence(identity_user)
    identity_user
  end

  def identity_username_available
    return if name.blank?

    existing_user = User.find_by(username: name)
    return if existing_user.nil? || existing_user == identity_user

    errors.add(:name, "is already used by a user account")
  end

  def ensure_identity_presence(user)
    return unless user

    begin
      user.mark_online!
    rescue => e
      Rails.logger.debug("Failed to mark bot_identity_id=#{user.id} online: #{e.class}")
    end
  end
end
