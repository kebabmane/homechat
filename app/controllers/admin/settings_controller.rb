module Admin
  class SettingsController < ApplicationController
    before_action :require_login
    before_action :ensure_admin!

    def edit
      @site_name = Setting.fetch(:site_name, "HomeChat")
      @allow_signups = ActiveModel::Type::Boolean.new.cast(Setting.fetch(:allow_signups, true))
      @require_signup_approval = ActiveModel::Type::Boolean.new.cast(Setting.fetch(:require_signup_approval, false))
      @pwa_enabled = ActiveModel::Type::Boolean.new.cast(Setting.fetch(:pwa_enabled, true))
      @pwa_short_name = Setting.fetch(:pwa_short_name, "HomeChat")
      @pwa_theme_color = Setting.fetch(:pwa_theme_color, "#2563eb")
      @pwa_bg_color = Setting.fetch(:pwa_bg_color, "#ffffff")
      @pwa_display = Setting.fetch(:pwa_display, "standalone")
      # API & Integration settings
      @api_enabled = ActiveModel::Type::Boolean.new.cast(Setting.fetch(:api_enabled, true))
      @home_assistant_enabled = ActiveModel::Type::Boolean.new.cast(Setting.fetch(:home_assistant_enabled, true))
      @webhook_base_url = Setting.fetch(:webhook_base_url, request.base_url)
      @litellm_host = Setting.fetch(:litellm_host, "")
      @litellm_default_model = Setting.fetch(:litellm_default_model, "")
      @litellm_api_key_present = Setting.fetch(:litellm_api_key, "").present?
      @litellm_models = []
      @litellm_error = nil

      # FCM Push Notification settings
      @fcm_enabled = Setting.fcm_enabled?
      @fcm_project_id = Setting.fcm_project_id || ""
      @fcm_client_email = Setting.fcm_client_email || ""
      @fcm_private_key_present = Setting.fcm_private_key.present?
      @fcm_configured = Setting.fcm_configured?
      @active_api_tokens_count = ApiToken.active.count

      if @litellm_host.present? && @litellm_api_key_present
        begin
          api_key = Setting.fetch(:litellm_api_key, nil)
          @litellm_models = LiteLlm::Client.new(host: @litellm_host, api_key: api_key).models
        rescue LiteLlm::Error => e
          @litellm_error = e.message
        end
      elsif @litellm_host.present?
        @litellm_error = "LiteLLM API key is required to fetch models."
      end
    end

    def update
      Setting.set(:site_name, params[:site_name].presence || "HomeChat")
      Setting.set(:allow_signups, ActiveModel::Type::Boolean.new.cast(params[:allow_signups]))
      Setting.set(:require_signup_approval, ActiveModel::Type::Boolean.new.cast(params[:require_signup_approval]))
      Setting.set(:pwa_enabled, ActiveModel::Type::Boolean.new.cast(params[:pwa_enabled]))
      Setting.set(:pwa_short_name, params[:pwa_short_name].presence || params[:site_name].presence || "HomeChat")
      Setting.set(:pwa_theme_color, params[:pwa_theme_color].presence || "#2563eb")
      Setting.set(:pwa_bg_color, params[:pwa_bg_color].presence || "#ffffff")
      Setting.set(:pwa_display, params[:pwa_display].presence || "standalone")
      # API & Integration settings
      Setting.set(:api_enabled, ActiveModel::Type::Boolean.new.cast(params[:api_enabled]))
      Setting.set(:home_assistant_enabled, ActiveModel::Type::Boolean.new.cast(params[:home_assistant_enabled]))
      Setting.set(:webhook_base_url, params[:webhook_base_url].presence || request.base_url)
      litellm_host = params[:litellm_host].to_s.strip
      default_model = params[:litellm_default_model].to_s.strip
      if litellm_host.present?
        Setting.set(:litellm_host, litellm_host)
      else
        Setting.where(key: "litellm_host").delete_all
      end

      if default_model.present?
        Setting.set(:litellm_default_model, default_model)
      else
        Setting.where(key: "litellm_default_model").delete_all
      end

      if ActiveModel::Type::Boolean.new.cast(params[:reset_litellm_api_key])
        Setting.where(key: "litellm_api_key").delete_all
      elsif params[:litellm_api_key].present?
        Setting.set(:litellm_api_key, params[:litellm_api_key].to_s.strip)
      end

      # FCM Push Notification settings
      Setting.fcm_enabled = ActiveModel::Type::Boolean.new.cast(params[:fcm_enabled])

      if params[:fcm_project_id].present?
        Setting.fcm_project_id = params[:fcm_project_id].to_s.strip
      else
        Setting.where(key: Setting::FCM_PROJECT_ID_KEY).delete_all
      end

      if params[:fcm_client_email].present?
        Setting.fcm_client_email = params[:fcm_client_email].to_s.strip
      else
        Setting.where(key: Setting::FCM_CLIENT_EMAIL_KEY).delete_all
      end

      if ActiveModel::Type::Boolean.new.cast(params[:reset_fcm_private_key])
        Setting.where(key: Setting::FCM_PRIVATE_KEY_KEY).delete_all
      elsif params[:fcm_private_key].present?
        Setting.fcm_private_key = params[:fcm_private_key].to_s.strip
      end

      api_key = Setting.fetch(:litellm_api_key, nil)
      if litellm_host.present?
        if api_key.blank?
          redirect_to edit_admin_settings_path, alert: "Settings saved. Add a LiteLLM API key to validate the connection." and return
        else
          begin
            LiteLlm::Client.new(host: litellm_host, api_key: api_key).models
          rescue LiteLlm::Error => e
            redirect_to edit_admin_settings_path, alert: "Settings saved, but LiteLLM validation failed: #{e.message}" and return
          end
        end
      end

      AuditLog.log(
        action: "admin.settings_updated",
        user: current_user,
        resource: current_user,
        ip_address: request.remote_ip,
        user_agent: request.user_agent,
        metadata: {
          changed_keys: changed_setting_keys(params),
          litellm_host_present: params[:litellm_host].present?,
          litellm_api_key_changed: params[:litellm_api_key].present? || params[:reset_litellm_api_key].present?,
          fcm_changed: params[:fcm_project_id].present? || params[:fcm_private_key].present? || params[:reset_fcm_private_key].present?
        }
      )

      redirect_to edit_admin_settings_path, notice: "Server settings saved."
    end

    private

    # Returns the list of non-secret setting keys that were submitted (for audit log).
    def changed_setting_keys(params)
      keys = %i[site_name allow_signups require_signup_approval pwa_enabled pwa_short_name
                pwa_theme_color pwa_bg_color pwa_display api_enabled home_assistant_enabled
                webhook_base_url litellm_host litellm_default_model fcm_enabled fcm_project_id
                fcm_client_email]
      keys.select { |k| params[k].present? }
    end

    def ensure_admin!
      redirect_to dashboard_path, alert: "Admins only." unless current_user&.admin?
    end
  end
end
