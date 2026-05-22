class Api::V1::MetricsController < Api::V1::BaseController
  # Skip authentication for health metrics (admin token required for detailed metrics)
  skip_before_action :authenticate_api_request, only: [ :health ]
  before_action :require_admin_token, only: [ :index ]

  # GET /api/v1/metrics/health
  # Basic health check - no auth required
  def health
    render json: {
      status: "ok",
      timestamp: Time.current.iso8601,
      version: Rails.application.class.module_parent_name
    }
  end

  # GET /api/v1/metrics
  # Detailed metrics - requires admin authentication
  def index
    metrics = gather_metrics

    respond_to do |format|
      format.json { render json: metrics }
      format.text { render plain: prometheus_format(metrics), content_type: "text/plain" }
      format.any { render json: metrics }
    end
  end

  private

  def require_admin_token
    unless current_api_user&.admin?
      render json: { error: "Admin access required" }, status: :forbidden
    end
  end

  def gather_metrics
    {
      timestamp: Time.current.iso8601,
      application: {
        name: Rails.application.class.module_parent_name,
        environment: Rails.env,
        ruby_version: RUBY_VERSION,
        rails_version: Rails::VERSION::STRING
      },
      database: database_metrics,
      users: user_metrics,
      channels: channel_metrics,
      messages: message_metrics,
      api_tokens: api_token_metrics,
      system: system_metrics
    }
  end

  def database_metrics
    {
      adapter: ActiveRecord::Base.connection.adapter_name,
      pool_size: ActiveRecord::Base.connection_pool.size,
      connections_in_use: ActiveRecord::Base.connection_pool.connections.count(&:in_use?),
      waiting_in_queue: ActiveRecord::Base.connection_pool.num_waiting_in_queue
    }
  end

  def user_metrics
    {
      total: User.count,
      admins: User.where(role: "admin").count,
      online: User.where(is_online: true).count,
      recently_active: User.where("last_seen_at > ?", 24.hours.ago).count,
      locked: User.where("locked_until > ?", Time.current).count
    }
  end

  def channel_metrics
    {
      total: Channel.count,
      public: Channel.where(channel_type: "public").count,
      private: Channel.where(channel_type: "private").count,
      dm: Channel.where(channel_type: "dm").count,
      active_today: Channel.joins(:messages).where("messages.created_at > ?", 24.hours.ago).distinct.count
    }
  end

  def message_metrics
    {
      total: Message.count,
      today: Message.where("created_at > ?", 24.hours.ago).count,
      this_hour: Message.where("created_at > ?", 1.hour.ago).count,
      with_attachments: Message.joins(:files_attachments).distinct.count
    }
  end

  def api_token_metrics
    {
      total: ApiToken.count,
      active: ApiToken.where(active: true).count,
      used_today: ApiToken.where("last_used_at > ?", 24.hours.ago).count
    }
  end

  def system_metrics
    {
      memory_mb: memory_usage_mb,
      uptime_seconds: process_uptime,
      pid: Process.pid
    }
  end

  def memory_usage_mb
    # Get memory usage from /proc on Linux, or use Ruby's built-in on other platforms
    if File.exist?("/proc/#{Process.pid}/status")
      File.read("/proc/#{Process.pid}/status").match(/VmRSS:\s+(\d+)/)[1].to_i / 1024
    else
      # Fallback: use ObjectSpace (less accurate)
      GC.stat[:heap_live_slots] * 40 / 1024 / 1024
    end
  rescue StandardError
    nil
  end

  def process_uptime
    if defined?(Rails.application.config.boot_time)
      (Time.current - Rails.application.config.boot_time).to_i
    else
      nil
    end
  end

  def prometheus_format(metrics)
    lines = []

    # Flatten metrics into Prometheus format
    add_prometheus_metric(lines, "homechat_users_total", metrics[:users][:total], "Total number of users")
    add_prometheus_metric(lines, "homechat_users_online", metrics[:users][:online], "Number of online users")
    add_prometheus_metric(lines, "homechat_users_locked", metrics[:users][:locked], "Number of locked users")
    add_prometheus_metric(lines, "homechat_channels_total", metrics[:channels][:total], "Total number of channels")
    add_prometheus_metric(lines, "homechat_messages_total", metrics[:messages][:total], "Total number of messages")
    add_prometheus_metric(lines, "homechat_messages_today", metrics[:messages][:today], "Messages in last 24 hours")
    add_prometheus_metric(lines, "homechat_api_tokens_active", metrics[:api_tokens][:active], "Active API tokens")
    add_prometheus_metric(lines, "homechat_db_connections_in_use", metrics[:database][:connections_in_use], "Database connections in use")

    if metrics[:system][:memory_mb]
      add_prometheus_metric(lines, "homechat_memory_mb", metrics[:system][:memory_mb], "Memory usage in MB")
    end

    lines.join("\n")
  end

  def add_prometheus_metric(lines, name, value, help)
    lines << "# HELP #{name} #{help}"
    lines << "# TYPE #{name} gauge"
    lines << "#{name} #{value}"
  end
end
