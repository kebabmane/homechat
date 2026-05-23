class UserKey < ApplicationRecord
  belongs_to :user
  validates :encrypted_hmac_key, presence: true
  validates :user_id, uniqueness: true
end
