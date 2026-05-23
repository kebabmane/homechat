module RateLimited
  extend ActiveSupport::Concern

  STORE = {}
  STORE_MUTEX = Mutex.new

  class_methods do
    def rate_limit(*actions, max:, period:)
      @rate_limits ||= {}
      actions.each do |action|
        @rate_limits[action.to_sym] = { max: max, period: period }
      end
    end

    def rate_limits
      @rate_limits || {}
    end
  end

  def perform_action(data)
    action = data["action"]&.to_sym
    limit = self.class.rate_limits[action]

    if limit
      unless throttle_allowed?(action, limit[:max], limit[:period])
        Rails.logger.warn "[RateLimited] user_id=#{current_user&.id || 'anonymous'} exceeded rate limit on #{self.class.name}##{action}"
        return
      end
    end

    super
  end

  private

  def throttle_allowed?(action, max, period)
    key = "#{self.class.name}:#{current_user&.id || connection.connection_identifier}:#{action}"
    now = Time.current.to_f
    window_start = now - period

    STORE_MUTEX.synchronize do
      STORE[key] ||= []
      STORE[key].delete_if { |t| t < window_start }

      if STORE[key].size >= max
        false
      else
        STORE[key] << now
        true
      end
    end
  end
end
