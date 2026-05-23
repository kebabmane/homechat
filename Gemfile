source "https://rubygems.org"

ruby ">= 4.0.0", "< 5.0"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.1.3"
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem "propshaft"
# Use sqlite3 as the database for Active Record
gem "sqlite3", ">= 2.1"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", "~> 8.0"
# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem "importmap-rails"
# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"
# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails"
# Use Tailwind CSS [https://github.com/rails/tailwindcss-rails]
gem "tailwindcss-rails"
# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem "jbuilder"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
gem "bcrypt", "~> 3.1.22"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ mingw mswin x64_mingw jruby ]

# Use the database-backed adapters for Rails.cache, Active Job, and Action Cable
gem "solid_cache"
gem "solid_queue"
gem "solid_cable"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Deploy this application anywhere as a Docker container [https://kamal-deploy.org]
gem "kamal", require: false
# The precompiled arm64-darwin package does not allow Ruby 4.x yet.
gem "bcrypt_pbkdf", force_ruby_platform: true

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
gem "image_processing", "~> 1.2"
# The precompiled arm64-darwin ffi package does not ship Ruby 4.0 native extensions yet.
gem "ffi", force_ruby_platform: true

# mDNS service discovery
gem "dnssd"

# Rack middleware for rate limiting and blocking
gem "rack-attack"

# TOTP-based two-factor authentication
gem "rotp"
gem "rqrcode"

# Verify Ed25519 signatures used by mobile E2EE device/key-share envelopes.
gem "ed25519"

# Structured JSON logging for production
gem "lograge"

# Log sanitization - filter sensitive data from logs
gem "logstop"
gem "ip_anonymizer"

# Google authentication for FCM (Firebase Cloud Messaging)
gem "googleauth"

# API documentation with OpenAPI/Swagger
gem "rswag-api"
gem "rswag-ui"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri mingw mswin x64_mingw ], require: false

  # N+1 query detection [https://github.com/flyerhzm/bullet]
  gem "bullet"

  # API documentation specs
  gem "rswag-specs"

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", "~> 8.0", require: false

  # Checks for vulnerable versions of gems [https://github.com/postmodern/bundler-audit]
  gem "bundler-audit", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false

  # ERB template linting [https://github.com/Shopify/erb-lint]
  gem "erb_lint", require: false

  # Code smell detection [https://github.com/troessner/reek]
  gem "reek", require: false

  # Test coverage reporting [https://github.com/simplecov-ruby/simplecov]
  gem "simplecov", require: false

  # Code complexity analysis [https://github.com/seattlerb/flog]
  gem "flog", require: false

  # Code duplication detection [https://github.com/seattlerb/flay]
  gem "flay", require: false
end

group :test do
  gem "capybara", require: false
  gem "selenium-webdriver", require: false

  # HTTP request stubbing for external API tests
  gem "webmock", require: false

  # Minitest pinned to 5.x for Rails 8 compatibility
  gem "minitest", "~> 5.25", require: false
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"

  # Process manager for Procfile-based development server [https://github.com/ddollar/foreman]
  gem "foreman"
end
