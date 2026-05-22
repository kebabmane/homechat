class AuditLog < ApplicationRecord
  REDACTED_VALUE = "[REDACTED]".freeze
  SENSITIVE_KEY_PATTERN = /
    passw|email|secret|token|key|crypt|salt|certificate|otp|ssn|cvv|cvc|
    authorization|cookie|message|content|body|payload|caption|title|sender|
    signature|hmac|fcm|username|room_id|filename
  /ix

  belongs_to :user, optional: true

  validates :action, presence: true
  validates :resource_type, presence: true

  # Common audit actions
  ACTIONS = {
    # User actions
    user_created: "user.created",
    user_updated: "user.updated",
    user_deleted: "user.deleted",
    user_role_changed: "user.role_changed",
    user_locked: "user.locked",
    user_unlocked: "user.unlocked",

    # Authentication actions
    login_success: "auth.login_success",
    login_failed: "auth.login_failed",
    logout: "auth.logout",
    password_changed: "auth.password_changed",
    two_factor_enabled: "auth.2fa_enabled",
    two_factor_disabled: "auth.2fa_disabled",

    # Channel actions
    channel_created: "channel.created",
    channel_updated: "channel.updated",
    channel_deleted: "channel.deleted",

    # Bot actions
    bot_created: "bot.created",
    bot_updated: "bot.updated",
    bot_deleted: "bot.deleted",
    bot_activated: "bot.activated",
    bot_deactivated: "bot.deactivated",

    # Token actions
    token_created: "token.created",
    token_regenerated: "token.regenerated",
    token_deactivated: "token.deactivated",

    # Settings actions
    settings_updated: "settings.updated"
  }.freeze

  scope :recent, -> { order(created_at: :desc) }
  scope :for_user, ->(user) { where(user: user) }
  scope :for_resource, ->(type, id) { where(resource_type: type, resource_id: id) }
  scope :by_action, ->(action) { where(action: action) }
  scope :since, ->(time) { where("created_at >= ?", time) }

  class << self
    def log(action:, user: nil, resource: nil, ip_address: nil, user_agent: nil, changes: nil, metadata: nil)
      create!(
        action: action,
        user: user,
        resource_type: resource&.class&.name || "System",
        resource_id: resource&.id,
        ip_address: ip_address,
        user_agent: user_agent&.truncate(500),
        changes_made: sanitize_object(changes),
        metadata: sanitize_object(metadata)
      )
    rescue => e
      Rails.logger.error "Failed to create audit log: #{e.class}"
      nil
    end

    def log_admin_action(action:, admin:, resource:, request:, changes: nil, metadata: nil)
      log(
        action: action,
        user: admin,
        resource: resource,
        ip_address: request.remote_ip,
        user_agent: request.user_agent,
        changes: changes,
        metadata: metadata&.merge(admin_action: true)
      )
    end

    private

    def sanitize_object(value, key: nil)
      return REDACTED_VALUE if sensitive_key?(key)

      case value
      when Hash
        value.each_with_object({}) do |(child_key, child_value), sanitized|
          sanitized[child_key.to_s] = sanitize_object(child_value, key: child_key)
        end
      when Array
        value.map { |item| sanitize_object(item, key: key) }
      else
        value
      end
    end

    def sensitive_key?(key)
      key.present? && key.to_s.match?(SENSITIVE_KEY_PATTERN)
    end
  end

  def admin_action?
    metadata&.dig("admin_action") == true
  end

  def changes_summary
    return nil if changes_made.blank?

    changes_made.map do |key, (old_val, new_val)|
      "#{key}: #{old_val.inspect} → #{new_val.inspect}"
    end.join(", ")
  end
end
