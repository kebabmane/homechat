class Bot < ApplicationRecord
  validates :name, presence: true, uniqueness: true
  validates :bot_type, presence: true, inclusion: { in: %w[webhook api] }
  validates :webhook_id, presence: true, if: -> { bot_type == 'webhook' }
  validates :webhook_id, uniqueness: true, allow_blank: true
  validates :webhook_secret, presence: true, if: -> { bot_type == 'webhook' }
  
  scope :active, -> { where(active: true) }
  scope :webhooks, -> { where(bot_type: 'webhook') }
  scope :api_bots, -> { where(bot_type: 'api') }
  
  before_validation :set_defaults
  
  # Association with messages (if you want to track bot messages)
  has_many :messages, foreign_key: :user_id, dependent: :destroy
  
  def webhook_url(base_url)
    return nil unless webhook_id.present?
    "#{base_url}/api/v1/webhooks/#{webhook_id}"
  end
  
  def deactivate!
    update!(active: false)
  end
  
  def activate!
    update!(active: true)
  end
  
  def webhook?
    bot_type == 'webhook'
  end
  
  def api_bot?
    bot_type == 'api'
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
    return false unless signature_header.to_s.start_with?('sha256=')

    signature = signature_header.to_s.sub(/^sha256=/, '')
    return false if signature.blank?

    # Calculate expected signature
    expected_signature = OpenSSL::HMAC.hexdigest('SHA256', webhook_secret, payload)

    # Secure comparison to prevent timing attacks
    ActiveSupport::SecurityUtils.secure_compare(signature, expected_signature)
  end

  private

  def set_defaults
    self.active = true if active.nil?
    self.bot_type = 'webhook' if bot_type.blank?
    self.webhook_id = SecureRandom.uuid if webhook? && webhook_id.blank?
    self.webhook_secret = SecureRandom.hex(32) if webhook? && webhook_secret.blank?
  end
end
