class ChannelKeyShare < ApplicationRecord
  belongs_to :channel
  belongs_to :recipient, class_name: "User", foreign_key: :recipient_user_id
  belongs_to :sender, class_name: "User", foreign_key: :sender_user_id

  validates :recipient_device_id, presence: true
  validates :sender_device_id, presence: true
  validates :sender_key_fingerprint, presence: true
  validates :encrypted_channel_key, presence: true
  validates :signature, presence: true
  validates :key_epoch, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :recipient_user_id, uniqueness: { scope: [ :channel_id, :recipient_device_id ] }
end
