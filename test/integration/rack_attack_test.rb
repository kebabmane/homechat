require "test_helper"

class RackAttackTest < ActionDispatch::IntegrationTest
  def setup
    @user = create_user(username: "rackattack_user", password: "password123")
    @rack_attack_enabled = Rack::Attack.enabled
    @rack_attack_store = Rack::Attack.cache.store

    Rack::Attack.enabled = true
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
    Rack::Attack.reset!
  end

  def teardown
    Rack::Attack.reset!
    Rack::Attack.cache.store = @rack_attack_store
    Rack::Attack.enabled = @rack_attack_enabled
  end

  test "throttles login attempts by IP" do
    # Exhaust the IP-based login limit (5 per 20 sec)
    5.times do
      post signin_path, params: { username: @user.username, password: "wrongpass" }
    end

    # Next attempt from same IP should be throttled
    post signin_path, params: { username: @user.username, password: "wrongpass" }
    assert_response :too_many_requests
    assert_equal 429, response.status
  end

  test "throttles login attempts by username across IPs" do
    # Exhaust the username-based login limit (5 per 20 sec)
    5.times do |i|
      # Simulate different IPs by manipulating the remote_ip header
      post signin_path,
           params: { username: @user.username, password: "wrongpass" },
           headers: { "REMOTE_ADDR" => "10.0.0.#{i}" }
    end

    # Next attempt for same username from yet another IP should be throttled
    post signin_path,
         params: { username: @user.username, password: "wrongpass" },
         headers: { "REMOTE_ADDR" => "10.0.0.99" }
    assert_response :too_many_requests
  end

  test "allows successful login after throttle window resets" do
    # A single failed attempt should not throttle
    post signin_path, params: { username: @user.username, password: "wrongpass" }
    assert_response :unprocessable_content

    # Successful login should still work
    post signin_path, params: { username: @user.username, password: "password123" }
    assert_response :redirect
  end

  test "throttles API signin by IP" do
    5.times do
      post api_v1_signin_path, params: { username: @user.username, password: "wrongpass" }
    end

    post api_v1_signin_path, params: { username: @user.username, password: "wrongpass" }
    assert_response :too_many_requests
  end

  test "throttles API signin by username" do
    5.times do |i|
      post api_v1_signin_path,
           params: { username: @user.username, password: "wrongpass" },
           headers: { "REMOTE_ADDR" => "10.0.0.#{i}" }
    end

    post api_v1_signin_path,
         params: { username: @user.username, password: "wrongpass" },
         headers: { "REMOTE_ADDR" => "10.0.0.99" }
    assert_response :too_many_requests
  end
end
