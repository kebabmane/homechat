require "test_helper"

class DiscoveryServiceTest < ActiveSupport::TestCase
  def setup
    @service = DiscoveryService.new(server_name: "Test Server", port: 3000)
  end

  def teardown
    @service.stop if @service.running?
  end

  test "initializes with custom server name and port" do
    service = DiscoveryService.new(server_name: "Custom Name", port: 8080)

    assert_equal "Custom Name", service.server_name
    assert_equal 8080, service.port
  end

  test "initializes with default values when not provided" do
    service = DiscoveryService.new

    assert_not_nil service.server_name
    assert_not_nil service.port
    assert_includes [3000, 80], service.port # Development or production default
  end

  test "running? returns false initially" do
    assert_not @service.running?
  end

  test "start sets running to true" do
    skip "DNSSD requires mDNS daemon which may not be available in test environment"

    @service.start
    assert @service.running?
  end

  test "stop sets running to false" do
    skip "DNSSD requires mDNS daemon which may not be available in test environment"

    @service.start
    @service.stop
    assert_not @service.running?
  end

  test "restart stops and starts service" do
    skip "DNSSD requires mDNS daemon which may not be available in test environment"

    @service.start
    assert @service.running?

    @service.restart
    assert @service.running?
  end

  test "stop does nothing if not running" do
    assert_nothing_raised do
      @service.stop
    end
    assert_not @service.running?
  end

  test "start does nothing if already running" do
    skip "DNSSD requires mDNS daemon which may not be available in test environment"

    @service.start
    @service.start # Should not raise

    assert @service.running?
  end

  test "txt_record is built correctly" do
    assert_not_nil @service.txt_record
  end

  test "service type constant is defined" do
    assert_equal "_homechat._tcp.", DiscoveryService::SERVICE_TYPE
  end

  test "service domain constant is defined" do
    assert_equal "local.", DiscoveryService::SERVICE_DOMAIN
  end
end
