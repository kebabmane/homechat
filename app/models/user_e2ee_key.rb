class UserE2eeKey < ApplicationRecord
  belongs_to :user
  validates :device_id, presence: true, format: { with: E2eePolicy::DEVICE_ID_FORMAT }
  validates :encryption_public_key, presence: true
  validates :signing_public_key, presence: true
  validates :key_fingerprint, presence: true
  validates :user_id, uniqueness: { scope: :device_id }
  before_validation :set_published_at, on: :create
  before_validation :sync_legacy_public_key

  private

  def set_published_at
    self.published_at ||= Time.current
    self.first_published_at ||= published_at
  end

  def sync_legacy_public_key
    self.public_key = encryption_public_key if encryption_public_key.present?
  end
end
