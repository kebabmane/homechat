ENV["RAILS_ENV"] ||= "test"
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
