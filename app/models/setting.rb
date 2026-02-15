class Setting < ApplicationRecord
  validates :key, presence: true, uniqueness: true

  # FCM Settings Keys
  FCM_ENABLED_KEY = "fcm_enabled".freeze
  FCM_PROJECT_ID_KEY = "fcm_project_id".freeze
  FCM_PRIVATE_KEY_KEY = "fcm_private_key".freeze
  FCM_CLIENT_EMAIL_KEY = "fcm_client_email".freeze

  def self.fetch(key, default = nil)
    rec = find_by(key: key.to_s)
    if rec&.value
      begin
        parsed = YAML.safe_load(rec.value, permitted_classes: [ Symbol ], aliases: true)
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

  # MARK: - FCM Push Notification Settings

  def self.fcm_enabled?
    fetch(FCM_ENABLED_KEY, false) == true || fetch(FCM_ENABLED_KEY, "false") == "true"
  end

  def self.fcm_enabled=(value)
    set(FCM_ENABLED_KEY, value.to_s == "true" || value == true)
  end

  def self.fcm_project_id
    fetch(FCM_PROJECT_ID_KEY, nil)
  end

  def self.fcm_project_id=(value)
    set(FCM_PROJECT_ID_KEY, value.to_s)
  end

  def self.fcm_private_key
    fetch(FCM_PRIVATE_KEY_KEY, nil)
  end

  def self.fcm_private_key=(value)
    set(FCM_PRIVATE_KEY_KEY, value.to_s)
  end

  def self.fcm_client_email
    fetch(FCM_CLIENT_EMAIL_KEY, nil)
  end

  def self.fcm_client_email=(value)
    set(FCM_CLIENT_EMAIL_KEY, value.to_s)
  end

  def self.fcm_configured?
    fcm_enabled? &&
      fcm_project_id.present? &&
      fcm_private_key.present? &&
      fcm_client_email.present?
  end

  def self.fcm_credentials
    return nil unless fcm_configured?

    {
      project_id: fcm_project_id,
      private_key: fcm_private_key,
      client_email: fcm_client_email
    }
  end
end

