# Lograge configuration for structured JSON logging in production
# This replaces verbose Rails request logging with single-line JSON entries

Rails.application.configure do
  # Enable lograge only in production (or staging)
  config.lograge.enabled = Rails.env.production? || ENV["LOGRAGE_ENABLED"] == "true"

  # Use JSON formatter for log aggregation tools (Datadog, Splunk, ELK, etc.)
  config.lograge.formatter = Lograge::Formatters::Json.new

  # Keep original Rails logger for non-request logs
  config.lograge.keep_original_rails_log = false

  # Add custom data to each log entry
  config.lograge.custom_options = lambda do |event|
    {
      # Request identification
      request_id: event.payload[:request_id],
      correlation_id: event.payload[:correlation_id],

      # Timing details
      time: Time.current.iso8601,
      duration_ms: event.duration.round(2),
      db_ms: event.payload[:db_runtime]&.round(2),
      view_ms: event.payload[:view_runtime]&.round(2),

      # User context (if available)
      user_id: event.payload[:user_id],
      user_username: event.payload[:user_username],

      # Request details
      remote_ip: event.payload[:remote_ip],
      user_agent: event.payload[:user_agent],

      # Additional context
      exception: event.payload[:exception]&.first,
      exception_message: event.payload[:exception]&.last,

      # Custom tags for filtering
      tags: event.payload[:tags]
    }.compact
  end

  # Add custom payload data from controllers
  config.lograge.custom_payload do |controller|
    user = controller.respond_to?(:current_user, true) ? controller.send(:current_user) : nil

    {
      request_id: controller.request.request_id,
      remote_ip: controller.request.remote_ip,
      user_agent: controller.request.user_agent,
      user_id: user&.id,
      user_username: user&.username,
      host: controller.request.host
    }
  end

  # Ignore certain paths from logging (health checks, assets, etc.)
  config.lograge.ignore_actions = [
    "Rails::HealthController#show",
    "Rails::PwaController#manifest",
    "Rails::PwaController#service_worker"
  ]

  # Ignore specific paths
  config.lograge.ignore_custom = lambda do |event|
    # Ignore asset requests
    event.payload[:path]&.start_with?("/assets/") ||
      # Ignore cable connections (they're logged separately)
      event.payload[:path]&.start_with?("/cable")
  end
end
