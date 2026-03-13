class Message < ApplicationRecord
  MENTION_REGEX = /(?:^|\s)@([A-Za-z0-9_]{3,50})/

  include ActionView::RecordIdentifier
  belongs_to :user
  belongs_to :channel
  has_many :message_receipts, dependent: :destroy
  has_many_attached :files
  attr_accessor :skip_chat_broadcast

  validates :content, presence: true, length: { minimum: 1, maximum: 2000 }
  validate :content_not_blank, unless: :e2ee?
  validate :validate_e2ee_fields

  # For E2EE records we store only a fixed placeholder in plaintext columns.
  before_validation :normalize_e2ee_fields

  # Quick win: strip HTML tags before saving to prevent stored XSS in web views.
  # Chat messages are plain text; legitimate angle-bracket use is preserved as &lt; / &gt;.
  before_save :sanitize_content

  scope :recent, -> { order(created_at: :desc) }
  scope :for_channel, ->(channel) { where(channel: channel) }
  
  def author_name
    user.username
  end

  def e2ee?
    content_encoding.to_s == E2eePolicy::REQUIRED_ENCODING
  end

  def transport_content
    e2ee? ? nil : content
  end

  # Single callback that delegates to service object
  after_create_commit :broadcast_message

  private

  def content_not_blank
    if content.present? && content.strip.blank?
      errors.add(:content, "cannot be blank")
    end
  end

  def sanitize_content
    # Strip HTML tags while preserving plain-text characters like & < >
    return if e2ee?

    self.content = content.to_s.gsub(/<\/?[a-zA-Z][^>]*>/, '')
  end

  def normalize_e2ee_fields
    return unless e2ee?

    self.content = E2eePolicy::PLACEHOLDER_CONTENT
  end

  def validate_e2ee_fields
    return unless e2ee?

    errors.add(:encrypted_content, "can't be blank") if encrypted_content.blank?
    errors.add(:content_hmac, "can't be blank") if content_hmac.blank?
    if E2eePolicy.required_for_channel?(channel)
      errors.add(:sender_device_id, "can't be blank") if respond_to?(:sender_device_id) && sender_device_id.blank?
      errors.add(:e2ee_version, "can't be blank") if respond_to?(:e2ee_version) && e2ee_version.blank?
    end
  end

  def broadcast_message
    MessageBroadcaster.new(self).call
  end
end
