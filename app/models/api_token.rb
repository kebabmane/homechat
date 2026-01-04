class ApiToken < ApplicationRecord
  belongs_to :user, optional: true

  validates :name, presence: true, uniqueness: true
  validates :token_digest, presence: true, uniqueness: true

  before_validation :generate_token, on: :create
  before_validation :hash_token
  before_save :set_token_prefix

  attr_accessor :token

  scope :active, -> { where(active: true) }

  # Class-level cache for token validation (short TTL)
  @@token_cache = {}
  @@cache_ttl = 60.seconds

  def self.generate_for_integration(name = "Home Assistant", user = nil)
    # Use system user for integrations if no specific user provided
    system_user = user || User.find_by(username: 'system')
    create!(name: name, active: true, user: system_user)
  end

  def self.valid_token?(token_string)
    return nil if token_string.blank?

    # Check cache first
    cached = check_cache(token_string)
    return cached if cached

    # Extract prefix for faster lookup (first 8 chars of raw token)
    prefix = token_string[0..7]

    # Narrow down candidates using prefix index
    candidates = active.where(token_prefix: prefix)

    # Fall back to full scan if no prefix match (legacy tokens)
    candidates = active if candidates.empty?

    candidates.find_each do |token_record|
      begin
        if BCrypt::Password.new(token_record.token_digest) == peppered_token(token_string)
          token_record.update_columns(last_used_at: Time.current)
          cache_token(token_string, token_record.user)
          return token_record.user
        end
      rescue BCrypt::Errors::InvalidHash
        # Token might still use old SHA256 format, try that
        if token_record.token_digest == hash_token_string_sha256(token_string)
          # Upgrade to BCrypt and set prefix
          token_record.update!(
            token_digest: hash_token_string(token_string),
            token_prefix: token_string[0..7],
            last_used_at: Time.current
          )
          cache_token(token_string, token_record.user)
          return token_record.user
        end
      end
    end

    nil
  end

  def deactivate!
    update!(active: false)
    self.class.clear_cache
  end

  def regenerate!
    generate_token
    save!
    self.class.clear_cache
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

  def set_token_prefix
    if token.present?
      self.token_prefix = token[0..7]
    end
  end

  def self.hash_token_string(token)
    BCrypt::Password.create(peppered_token(token), cost: 12)
  end

  # Fallback for legacy SHA256 tokens during migration
  def self.hash_token_string_sha256(token)
    Digest::SHA256.hexdigest(peppered_token(token))
  end

  def self.peppered_token(token)
    # Use pepper from credentials, fallback to empty string for development
    pepper = Rails.application.credentials.dig(:api_token, :pepper) || ENV['API_TOKEN_PEPPER'] || ''
    "#{token}#{pepper}"
  end

  # Simple in-memory cache for token validation
  def self.check_cache(token_string)
    key = Digest::SHA256.hexdigest(token_string)
    entry = @@token_cache[key]

    if entry && entry[:expires_at] > Time.current
      entry[:user]
    else
      @@token_cache.delete(key)
      nil
    end
  end

  def self.cache_token(token_string, user)
    # Limit cache size
    if @@token_cache.size > 1000
      # Remove expired entries
      @@token_cache.delete_if { |_, v| v[:expires_at] < Time.current }
    end

    key = Digest::SHA256.hexdigest(token_string)
    @@token_cache[key] = {
      user: user,
      expires_at: Time.current + @@cache_ttl
    }
  end

  def self.clear_cache
    @@token_cache.clear
  end
end
