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

  before_validation :assign_default_scopes, on: :create
  before_validation :generate_token, on: :create
  before_validation :hash_token
  before_save :set_token_prefix

  attr_accessor :token

  # Ensure scopes is always an Array regardless of how the JSON was persisted
  def scopes
    val = super
    case val
    when Array  then val
    when String then JSON.parse(val) rescue []
    else []
    end
  end

  scope :active, -> { where(active: true) }
  scope :not_expired, -> { where("expires_at IS NULL OR expires_at > ?", Time.current) }
  scope :bots, -> { where(token_type: "bot") }

  # Cache configuration - uses Rails.cache (Redis in production)
  CACHE_TTL = 60.seconds
  CACHE_KEY_PREFIX = "api_token:v1:"

  def self.generate_for_integration(name = "Home Assistant", user = nil, scopes: [ "user:channels", "user:messages", "bot:post" ])
    # Use system user for integrations if no specific user provided
    system_user = user || User.find_by(username: "system")
    create!(name: name, active: true, user: system_user, token_type: "bot", scopes: scopes)
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
        if ActiveSupport::SecurityUtils.secure_compare(
             token_record.token_digest,
             hash_token_string_sha256(token_string)
           )
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

  # Blank scopes no longer imply full access. Existing blank-scope rows should be
  # backfilled by migration to explicit scopes before this code is deployed.
  def legacy_full_access?
    false
  end

  # Check if token has a specific scope
  def has_scope?(scope)
    return true if legacy_full_access?
    return true if scopes.include?("*")
    return true if scopes.include?(scope)

    # Check wildcard matches (e.g., "admin:*" covers "admin:users")
    category = scope.split(":").first
    return true if scopes.include?("#{category}:*")

    # Check channel wildcards (e.g., "channel:*:read" covers "channel:123:read")
    if scope.match?(/^channel:\d+:/)
      action = scope.split(":").last
      return true if scopes.include?("channel:*:#{action}")
    end

    false
  end

  # Check channel-specific access with permission level
  # Permission hierarchy: manage > write > read
  def can_access_channel?(channel, action = :read)
    return true if legacy_full_access?

    # user:channels scope grants read access to all channels (membership enforced by accessible_by?)
    return true if action.to_sym == :read && has_scope?("user:channels") && !bot_token?

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
    token_type == "bot"
  end

  # Prevent bot tokens from accessing user data
  def can_access_user_data?
    !bot_token? && (has_scope?("user:profile") || legacy_full_access?)
  end

  # Get the effective token type (defaults to 'user' for nil)
  def effective_token_type
    token_type || "user"
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
    if scopes.blank?
      errors.add(:scopes, "must include at least one explicit scope")
      return
    end

    scopes.each do |scope|
      next if scope == "*"
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
    errors.add(:expires_at, "must be in the future") if expires_at <= Time.current
  end

  def assign_default_scopes
    return if self[:scopes].present?

    self.scopes = default_scopes_for_type
  end

  def default_scopes_for_type
    case effective_token_type
    when "admin"
      [ "admin:*", *USER_SCOPES ]
    when "bot"
      BOT_SCOPES
    else
      user&.admin? ? [ "admin:*", *USER_SCOPES ] : USER_SCOPES
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
    pepper = Rails.application.credentials.dig(:api_token, :pepper) || ENV["API_TOKEN_PEPPER"]
    if pepper.blank? && Rails.env.production?
      raise "API_TOKEN_PEPPER must be configured in production (credentials or ENV)"
    end
    "#{token}#{pepper}"
  end

  # Redis-backed cache for token validation (uses Rails.cache)
  # Caches the token record ID to avoid storing ActiveRecord objects
  def self.check_cache(token_string)
    cache_key = "#{CACHE_KEY_PREFIX}#{Digest::SHA256.hexdigest(token_string)}"
    token_id = Rails.cache.read(cache_key)

    return nil unless token_id

    # Fetch the token record from the database
    token_record = find_by(id: token_id)
    return nil unless token_record

    # Check if the token itself has expired
    return nil if token_record.expired?
    return nil unless token_record.active?

    token_record
  end

  def self.cache_token(token_string, token_record)
    cache_key = "#{CACHE_KEY_PREFIX}#{Digest::SHA256.hexdigest(token_string)}"
    # Store only the token ID, not the full record
    Rails.cache.write(cache_key, token_record.id, expires_in: CACHE_TTL)
  end

  def self.clear_cache
    # Clear all cached tokens by deleting keys with our prefix
    # This works best with Redis, for memory store it just doesn't do much
    if Rails.cache.respond_to?(:delete_matched)
      Rails.cache.delete_matched("#{CACHE_KEY_PREFIX}*")
    end
  end

  def self.invalidate_token_cache(token_string)
    cache_key = "#{CACHE_KEY_PREFIX}#{Digest::SHA256.hexdigest(token_string)}"
    Rails.cache.delete(cache_key)
  end
end
