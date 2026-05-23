require "test_helper"

class ProductionSecurityConfigTest < ActiveSupport::TestCase
  test "production config enforces explicit secure transport mode" do
    source = File.read(Rails.root.join("config/environments/production.rb"))

    assert_includes source, "Insecure transport configuration in production"
    assert_includes source, "allow_insecure_http = ENV[\"RAILS_ALLOW_INSECURE_HTTP\"] == \"true\" || home_assistant_addon"
    assert_includes source, "if !config.force_ssl && !config.assume_ssl && !allow_insecure_http"
  end

  test "action cable production origins only allow http when insecure http is explicit" do
    source = File.read(Rails.root.join("config/environments/production.rb"))

    assert_includes source, "\\Ahttps:\\/\\/localhost"
    assert_includes source, "if allow_insecure_http"
    assert_includes source, "\\Ahttp:\\/\\/localhost"
    assert_not_includes source, "\\Ahttps?:\\/\\/localhost"
  end
end
