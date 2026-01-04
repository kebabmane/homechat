# Concern for account lockout functionality
# Add to User model with: include AccountLockable

module AccountLockable
  extend ActiveSupport::Concern

  MAX_FAILED_ATTEMPTS = 5
  LOCKOUT_DURATION = 15.minutes
  FAILED_ATTEMPT_RESET_AFTER = 1.hour

  included do
    # Ensure columns exist before defining methods
    # failed_attempts, locked_until, last_failed_at
  end

  def locked?
    locked_until.present? && locked_until > Time.current
  end

  def lock_access!
    update!(
      locked_until: Time.current + LOCKOUT_DURATION,
      failed_attempts: MAX_FAILED_ATTEMPTS
    )

    AuditLog.log(
      action: AuditLog::ACTIONS[:user_locked],
      resource: self,
      metadata: { reason: "max_failed_attempts", locked_until: locked_until.iso8601 }
    )

    Rails.logger.warn "Account locked for user #{username} until #{locked_until}"
  end

  def unlock_access!
    update!(
      locked_until: nil,
      failed_attempts: 0,
      last_failed_at: nil
    )

    AuditLog.log(
      action: AuditLog::ACTIONS[:user_unlocked],
      resource: self
    )
  end

  def register_failed_attempt!
    # Reset counter if last failure was long ago
    if last_failed_at.present? && last_failed_at < FAILED_ATTEMPT_RESET_AFTER.ago
      self.failed_attempts = 0
    end

    self.failed_attempts += 1
    self.last_failed_at = Time.current

    if failed_attempts >= MAX_FAILED_ATTEMPTS
      lock_access!
    else
      save!
    end
  end

  def clear_failed_attempts!
    return unless failed_attempts > 0 || locked_until.present?

    update!(
      failed_attempts: 0,
      last_failed_at: nil,
      locked_until: nil
    )
  end

  def remaining_attempts
    [MAX_FAILED_ATTEMPTS - failed_attempts, 0].max
  end

  def lockout_remaining_time
    return nil unless locked?
    ((locked_until - Time.current) / 60).ceil
  end

  class_methods do
    def find_for_authentication(username:)
      user = find_by(username: username)
      return nil unless user

      if user.locked?
        Rails.logger.warn "Login attempt for locked account: #{username}"
        return nil
      end

      user
    end
  end
end
