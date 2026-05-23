ENV["RAILS_ENV"] ||= "test"

# Configure SimpleCov for test coverage
if ENV["COVERAGE"]
  require "simplecov"

  SimpleCov.command_name "rails-test-#{ENV.fetch('TEST_ENV_NUMBER', Process.pid)}"
  SimpleCov.use_merging true
  SimpleCov.merge_timeout 3600

  SimpleCov.start "rails" do
    add_filter "/vendor/"
    add_filter "/test/"
    add_filter "/config/"
    add_filter "/bin/"
    add_filter "/db/"

    # Track coverage for these directories
    add_group "Models", "app/models"
    add_group "Controllers", "app/controllers"
    add_group "Views", "app/views"
    add_group "Helpers", "app/helpers"
    add_group "Mailers", "app/mailers"
    add_group "Jobs", "app/jobs"
    add_group "Lib", "lib"

    # Set minimum coverage thresholds
    minimum_coverage 70

    # Output formats
    formatter SimpleCov::Formatter::MultiFormatter.new([
      SimpleCov::Formatter::HTMLFormatter,
      SimpleCov::Formatter::SimpleFormatter
    ])
  end
end

require_relative "../config/environment"
require "rails/test_help"
require "minitest/mock"
require_relative "support/openapi_response_assertions"

class ActiveSupport::TestCase
  # Run tests in parallel with specified workers
  parallelize(workers: ENV["COVERAGE"] ? 1 : :number_of_processors)

  teardown do
    # Clear in-memory WebSocket throttle store between tests
    if defined?(RateLimited)
      RateLimited::STORE_MUTEX.synchronize do
        RateLimited::STORE.clear
      end
    end
  end

  # Add more helper methods to be used by all tests here...
  def create_user(username: "user#{SecureRandom.hex(3)}", role: "user", password: "password123")
    User.create!(username: username, role: role, password: password, password_confirmation: password)
  end

  def sign_in_as(user, password: "password123")
    post "/signin", params: { username: user.username, password: password }
    assert_response :redirect, "Expected redirect after signin, got #{response.status}: #{response.body}"
    follow_redirect!
    # May redirect to dashboard or 2FA page
    assert_response :success
  end

  # Provide signout path helper for tests
  def signout_path
    "/signout"
  end
end

class ActionDispatch::IntegrationTest
  include OpenapiResponseAssertions
end
