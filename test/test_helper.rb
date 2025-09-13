ENV["RAILS_ENV"] ||= "test"

# Configure SimpleCov for test coverage
if ENV['COVERAGE']
  require 'simplecov'
  
  SimpleCov.start 'rails' do
    add_filter '/vendor/'
    add_filter '/test/'
    add_filter '/config/'
    add_filter '/bin/'
    add_filter '/db/'
    
    # Track coverage for these directories
    add_group 'Models', 'app/models'
    add_group 'Controllers', 'app/controllers'
    add_group 'Views', 'app/views'
    add_group 'Helpers', 'app/helpers'
    add_group 'Mailers', 'app/mailers'
    add_group 'Jobs', 'app/jobs'
    add_group 'Lib', 'lib'
    
    # Set minimum coverage thresholds
    minimum_coverage 80
    minimum_coverage_by_file 60
    
    # Output formats
    formatter SimpleCov::Formatter::MultiFormatter.new([
      SimpleCov::Formatter::HTMLFormatter,
      SimpleCov::Formatter::SimpleFormatter
    ])
  end
end

require_relative "../config/environment"
require "rails/test_help"

class ActiveSupport::TestCase
  # Run tests in parallel with specified workers
  parallelize(workers: :number_of_processors)

  # Add more helper methods to be used by all tests here...
  def create_user(username: "user#{SecureRandom.hex(3)}", role: "user", password: "secret")
    User.create!(username: username, role: role, password: password, password_confirmation: password)
  end

  def sign_in_as(user, password: "secret")
    post "/signin", params: { username: user.username, password: password }
    assert_response :redirect
    follow_redirect!
    assert_response :success
  end

  # Provide signout path helper for tests
  def signout_path
    "/signout"
  end
end
