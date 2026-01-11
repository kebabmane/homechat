class ApiToken < ApplicationRecord
  belongs_to :user, optional: true
  has_many :token_channel_assignments, dependent: :destroy
  has_many :channels, through: :token_channel_assignments

  # Token types
  TOKEN_TYPES = %w[user admin bot].freeze

  # Scope constants for reference
  ADMIN_SCOPES = %w[admin:* admin:users admin:tokens admin:bots admin:settings].freeze
  USER_SCOPES = %w[user:profile user:channels user:messages].freeze
  BOT_SCOPES = %w[bot:post].freeze
  CHANNEL_ACTIONS = %w[read write manage].freeze

  validates :name, presence: true, uniqueness: true
  validates :token_digest, presence: true, uniqueness: true
  validates :token_type, inclusion: { in: TOKEN_TYPES }, allow_nil: true
  validate :validate_scopes
  validate :validate_expiration, on: :create

  before_validation :generate_token, on: :create
  before_validation :hash_token
  before_save :set_token_prefix

  attr_accessor :token

  scope :active, -> { where(active: true) }
  scope :not_expired, -> { where('expires_at IS NULL OR expires_at > ?', Time.current) }
  scope :bots, -> { where(token_type: 'bot') }

  # Class-level cache for token validation (short TTL)
  @@token_cache = {}
  @@cache_ttl = 60.seconds

  def self.generate_for_integration(name = "Home Assistant", user = nil)
    # Use system user for integrations if no specific user provided
    system_user = user || User.find_by(username: 'system')
    create!(name: name, active: true, user: system_user)
  end

  # Returns the ApiToken record if valid, nil otherwise.
  # Note: This now returns the token record (not user) to support scope checking.
  def self.valid_token?(token_string)
    return nil if token_string.blank?

    # Check cache first
    cached = check_cache(token_string)
    return cached if cached

    # Extract prefix for faster lookup (first 8 chars of raw token)
    prefix = token_string[0..7]

    # Narrow down candidates using prefix index, filtering expired tokens
    candidates = active.not_expired.where(token_prefix: prefix)

    # Fall back to full scan if no prefix match (legacy tokens)
    candidates = active.not_expired if candidates.empty?

    candidates.find_each do |token_record|
      begin
        if BCrypt::Password.new(token_record.token_digest) == peppered_token(token_string)
          token_record.update_columns(last_used_at: Time.current)
          cache_token(token_string, token_record)
          return token_record
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
          cache_token(token_string, token_record)
          return token_record
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

  # Check if token has expired
  def expired?
    expires_at.present? && expires_at <= Time.current
  end

  # Legacy tokens (nil scopes or empty array) get full access for backward compatibility
  # Tokens with explicit scopes have restricted access
  def legacy_full_access?
    scopes.nil? || scopes.empty?
  end

  # Check if token has a specific scope
  def has_scope?(scope)
    return true if legacy_full_access?
    return true if scopes.include?('*')
    return true if scopes.include?(scope)

    # Check wildcard matches (e.g., "admin:*" covers "admin:users")
    category = scope.split(':').first
    return true if scopes.include?("#{category}:*")

    # Check channel wildcards (e.g., "channel:*:read" covers "channel:123:read")
    if scope.match?(/^channel:\d+:/)
      action = scope.split(':').last
      return true if scopes.include?("channel:*:#{action}")
    end

    false
  end

  # Check channel-specific access with permission level
  # Permission hierarchy: manage > write > read
  def can_access_channel?(channel, action = :read)
    return true if legacy_full_access?

    # Check direct scope match
    return true if has_scope?("channel:*:#{action}")
    return true if has_scope?("channel:#{channel.id}:#{action}")

    # Check permission hierarchy (higher permission implies lower)
    case action.to_sym
    when :read
      # write or manage implies read
      return true if has_scope?("channel:*:write") || has_scope?("channel:*:manage")
      return true if has_scope?("channel:#{channel.id}:write") || has_scope?("channel:#{channel.id}:manage")
    when :write
      # manage implies write
      return true if has_scope?("channel:*:manage")
      return true if has_scope?("channel:#{channel.id}:manage")
    end

    # Check explicit channel assignments
    assignment = token_channel_assignments.find_by(channel: channel)
    return false unless assignment

    case action.to_sym
    when :read then true # Any assignment grants read access
    when :write then assignment.can_write?
    when :manage then assignment.can_manage?
    else false
    end
  end

  # Bot token check
  def bot_token?
    token_type == 'bot'
  end

  # Prevent bot tokens from accessing user data
  def can_access_user_data?
    !bot_token? && (has_scope?('user:profile') || legacy_full_access?)
  end

  # Get the effective token type (defaults to 'user' for nil)
  def effective_token_type
    token_type || 'user'
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

  def validate_scopes
    return if scopes.blank?

    scopes.each do |scope|
      next if scope == '*'
      next if ADMIN_SCOPES.include?(scope)
      next if USER_SCOPES.include?(scope)
      next if BOT_SCOPES.include?(scope)
      next if scope.match?(/^channel:\*:(read|write|manage)$/)
      next if scope.match?(/^channel:\d+:(read|write|manage)$/)

      errors.add(:scopes, "contains invalid scope: #{scope}")
    end
  end

  def validate_expiration
    return if expires_at.blank?
    errors.add(:expires_at, 'must be in the future') if expires_at <= Time.current
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
  # Now caches the token record instead of just the user
  def self.check_cache(token_string)
    key = Digest::SHA256.hexdigest(token_string)
    entry = @@token_cache[key]

    if entry && entry[:cache_expires_at] > Time.current
      # Check if the token itself has expired
      token_record = entry[:token]
      return nil if token_record.expired?
      token_record
    else
      @@token_cache.delete(key)
      nil
    end
  end

  def self.cache_token(token_string, token_record)
    # Limit cache size
    if @@token_cache.size > 1000
      # Remove expired entries
      @@token_cache.delete_if { |_, v| v[:cache_expires_at] < Time.current }
    end

    key = Digest::SHA256.hexdigest(token_string)
    @@token_cache[key] = {
      token: token_record,
      cache_expires_at: Time.current + @@cache_ttl
    }
  end

  def self.clear_cache
    @@token_cache.clear
  end
end
