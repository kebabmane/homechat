# Bullet configuration for N+1 query detection
# Only enabled in development and test environments

if defined?(Bullet)
  Rails.application.configure do
    config.after_initialize do
      Bullet.enable = true

      # Show alerts in browser (development only)
      Bullet.alert = Rails.env.development?

      # Log to bullet.log
      Bullet.bullet_logger = true

      # Log to Rails logger
      Bullet.rails_logger = true

      # Add errors to browser console
      Bullet.console = Rails.env.development?

      # Log N+1 queries in test environment but don't raise (enable later after fixing existing issues)
      Bullet.raise = false

      # Add footer to pages showing N+1 queries
      Bullet.add_footer = Rails.env.development?

      # Detect N+1 queries
      Bullet.n_plus_one_query_enable = true

      # Detect unused eager loading
      Bullet.unused_eager_loading_enable = true

      # Detect counter cache opportunities
      Bullet.counter_cache_enable = true

      # Skip certain associations that are intentionally loaded separately
      # Bullet.add_safelist type: :n_plus_one_query, class_name: "Post", association: :comments

      # Skip certain controllers (e.g., admin dashboards where performance is less critical)
      # Bullet.skip_controller_path = ["admin/dashboard"]
    end
  end
end
