require "test_helper"

class ProductionSecurityConfigTest < ActiveSupport::TestCase
  test "production config enforces explicit secure transport mode" do
    source = File.read(Rails.root.join("config/environments/production.rb"))

    assert_includes source, "Insecure transport configuration in production"
    assert_includes source, "config.force_ssl = force_ssl_env || (!home_assistant_addon)"
  end

  test "action cable production origins are https only" do
    source = File.read(Rails.root.join("config/environments/production.rb"))

    assert_includes source, "\\Ahttps:\\/\\/localhost"
    assert_not_includes source, "\\Ahttps?:\\/\\/localhost"
  end
end
