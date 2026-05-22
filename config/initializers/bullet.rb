# Bullet configuration for N+1 query detection
# Only enabled in development and test environments
#
# NOTE: Bullet must be configured at the TOP LEVEL of the initializer.
# Settings inside config.after_initialize are applied too late — Bullet
# registers its Rack middleware during app build, before after_initialize runs.

if defined?(Bullet)
  # Temporarily disabled for Playwright UI testing.
  # Re-enable and configure the notification channels when testing is done.
  Bullet.enable = false

  # When re-enabling, use these settings (not alert: true — it blocks the browser):
  # Bullet.enable                   = true
  # Bullet.alert                    = false
  # Bullet.bullet_logger            = true
  # Bullet.rails_logger             = true
  # Bullet.console                  = false
  # Bullet.raise                    = false
  # Bullet.add_footer               = false
  # Bullet.n_plus_one_query_enable  = true
  # Bullet.unused_eager_loading_enable = true
  # Bullet.counter_cache_enable     = true
end
