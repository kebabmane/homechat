class ApiToken < ApplicationRecord
  validates :name, presence: true, uniqueness: true
  validates :token_digest, presence: true, uniqueness: true

  before_validation :generate_token, on: :create
  before_validation :hash_token

  attr_accessor :token
  
  scope :active, -> { where(active: true) }
  
  def self.generate_for_integration(name = "Home Assistant")
    create!(name: name, active: true)
  end
  
  def self.valid_token?(token_string)
    return false if token_string.blank?

    token_digest = hash_token_string(token_string)
    token_record = active.find_by(token_digest: token_digest)
    if token_record
      token_record.update(last_used_at: Time.current)
      true
    else
      false
    end
  end
  
  def deactivate!
    update!(active: false)
  end
  
  def regenerate!
    generate_token
    save!
  end
  
  def masked_token
    return nil if token.blank?
    "#{token[0..7]}#{'*' * (token.length - 12)}#{token[-4..-1]}"
  end

  def short_token
    return nil if token.blank?
    "...#{token[-4..-1]}"
  end
  
  private

  def generate_token
    return if @skip_generate
    self.token = SecureRandom.hex(32)
  end

  def hash_token
    if token.present?
      self.token_digest = self.class.hash_token_string(token)
    end
  end

  def self.hash_token_string(token)
    Digest::SHA256.hexdigest(token)
  end
end
