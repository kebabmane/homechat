class Setting < ApplicationRecord
  validates :key, presence: true, uniqueness: true

  def self.fetch(key, default = nil)
    rec = find_by(key: key.to_s)
    return YAML.safe_load(rec.value, permitted_classes: [Symbol], aliases: true) if rec&.value
    default
  end

  def self.set(key, value)
    rec = find_or_initialize_by(key: key.to_s)
    rec.value = value.is_a?(String) ? value : value.to_yaml
    rec.save!
  end
end

