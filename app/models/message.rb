class Message < ApplicationRecord
  MENTION_REGEX = /(?:^|\s)@([A-Za-z0-9_]{3,50})/

  # File upload limits
  MAX_FILES_PER_MESSAGE = 10
  MAX_FILE_SIZE = 10.megabytes
  ALLOWED_FILE_TYPES = %w[
    image/jpeg image/jpg image/png image/gif image/webp image/svg+xml
    video/mp4 video/webm video/ogg
    audio/mpeg audio/mp4 audio/ogg audio/wav audio/webm
    application/pdf text/plain
  ].freeze

  include ActionView::RecordIdentifier
  belongs_to :user
  belongs_to :channel
  has_many :message_receipts, dependent: :destroy
  has_many_attached :files
  attr_accessor :skip_chat_broadcast

  validates :content, presence: true, length: { minimum: 1, maximum: 2000 }
  validate :content_not_blank, unless: :e2ee?
  validate :validate_e2ee_fields
  validate :encrypted_messages_do_not_attach_files
  validate :files_validation

  # For E2EE records we store only a fixed placeholder in plaintext columns.
  before_validation :normalize_e2ee_fields

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
  after_update_commit :broadcast_update

  private

  def broadcast_update
    broadcast_replace_to channel, target: dom_id(self), partial: "messages/message", locals: { message: self }
  end

  def content_not_blank
    if content.present? && content.strip.blank?
      errors.add(:content, "cannot be blank")
    end
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

  def encrypted_messages_do_not_attach_files
    return unless e2ee? && files.attached?

    errors.add(:files, "are not supported on end-to-end encrypted messages")
  end

  def files_validation
    return unless files.attached?

    if files.count > MAX_FILES_PER_MESSAGE
      errors.add(:files, "cannot exceed #{MAX_FILES_PER_MESSAGE} per message")
      return
    end

    files.each do |file|
      if file.blob.byte_size > MAX_FILE_SIZE
        errors.add(:files, "#{file.filename} must be less than #{MAX_FILE_SIZE / 1.megabyte}MB")
      end

      unless ALLOWED_FILE_TYPES.include?(file.blob.content_type)
        errors.add(:files, "#{file.filename} has unsupported type (#{file.blob.content_type}). Allowed: images, videos, audio, PDF, plain text")
      end
    end
  end

  def broadcast_message
    MessageBroadcaster.new(self).call
  end
end
