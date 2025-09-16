class Setting < ApplicationRecord
  validates :key, presence: true, uniqueness: true

  def self.fetch(key, default = nil)
    rec = find_by(key: key.to_s)
    if rec&.value
      begin
        parsed = YAML.safe_load(rec.value, permitted_classes: [Symbol], aliases: true)
        # If YAML parsing returns the original string or parsed value, use it
        # Otherwise fall back to the raw string value
        parsed.nil? ? rec.value : parsed
      rescue Psych::SyntaxError
        # If YAML parsing fails, return the raw string value
        rec.value
      end
    else
      default
    end
  end

  def self.set(key, value)
    rec = find_or_initialize_by(key: key.to_s)
    rec.value = value.is_a?(String) ? value : value.to_yaml
    rec.save!
  end
end

