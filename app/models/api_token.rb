class ApiToken < ApplicationRecord
  validates :name, presence: true, uniqueness: true
  validates :token, presence: true, uniqueness: true
  
  before_validation :generate_token, on: :create
  
  scope :active, -> { where(active: true) }
  
  def self.generate_for_integration(name = "Home Assistant")
    create!(name: name, active: true)
  end
  
  def self.valid_token?(token_string)
    return false if token_string.blank?
    
    token_record = active.find_by(token: token_string)
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
    self.token = SecureRandom.hex(32)
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
    self.token = SecureRandom.hex(32) if token.blank?
  end
end
