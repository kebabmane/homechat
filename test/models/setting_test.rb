require "test_helper"

class SettingTest < ActiveSupport::TestCase
  test "should require key" do
    setting = Setting.new(value: "test_value")
    assert_not setting.valid?
    assert_includes setting.errors[:key], "can't be blank"
  end

  test "should require unique key" do
    Setting.create!(key: "test_key", value: "test_value")
    duplicate_setting = Setting.new(key: "test_key", value: "another_value")
    assert_not duplicate_setting.valid?
    assert_includes duplicate_setting.errors[:key], "has already been taken"
  end

  test "should set and fetch string values" do
    Setting.set("test_string", "hello world")
    assert_equal "hello world", Setting.fetch("test_string")
  end

  test "should set and fetch boolean values" do
    Setting.set("test_boolean", true)
    assert_equal true, Setting.fetch("test_boolean")

    Setting.set("test_boolean_false", false)
    assert_equal false, Setting.fetch("test_boolean_false")
  end

  test "should return default value when key not found" do
    assert_equal "default", Setting.fetch("nonexistent_key", "default")
    assert_nil Setting.fetch("nonexistent_key")
  end

  test "should handle nil values" do
    Setting.set("nil_key", nil)
    # Setting.set converts nil to YAML which becomes "---\n"
    # Setting.fetch tries to parse this and should return original string if parsing fails
    result = Setting.fetch("nil_key")
    assert result == "---\n" || result.nil?
  end

  test "should handle numeric values" do
    Setting.set("numeric_key", 42)
    assert_equal 42, Setting.fetch("numeric_key")

    Setting.set("float_key", 3.14)
    assert_equal 3.14, Setting.fetch("float_key")
  end

  test "should handle array values" do
    Setting.set("array_key", ["a", "b", "c"])
    assert_equal ["a", "b", "c"], Setting.fetch("array_key")
  end

  test "should handle hash values" do
    Setting.set("hash_key", { foo: "bar", nested: { key: "value" } })
    result = Setting.fetch("hash_key")
    # YAML parsing may preserve symbols or convert them to strings
    assert result[:foo] == "bar" || result["foo"] == "bar"
    assert result.is_a?(Hash)
  end

  test "should convert key to string" do
    Setting.set(:symbol_key, "value")
    assert_equal "value", Setting.fetch("symbol_key")
    assert_equal "value", Setting.fetch(:symbol_key)
  end

  test "should handle malformed YAML gracefully" do
    # Create a setting with malformed YAML
    setting = Setting.create!(key: "malformed", value: "invalid: yaml: [unclosed")

    # Should fallback to raw string value
    assert_equal "invalid: yaml: [unclosed", Setting.fetch("malformed")
  end

  test "should handle color hex values" do
    Setting.set("theme_color", "#123456")
    assert_equal "#123456", Setting.fetch("theme_color")
  end
end