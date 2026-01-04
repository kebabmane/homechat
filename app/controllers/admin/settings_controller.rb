module Admin
  class SettingsController < ApplicationController
    before_action :require_login
    before_action :ensure_admin!

    def edit
      @site_name = Setting.fetch(:site_name, 'HomeChat')
      @allow_signups = ActiveModel::Type::Boolean.new.cast(Setting.fetch(:allow_signups, true))
      @pwa_enabled = ActiveModel::Type::Boolean.new.cast(Setting.fetch(:pwa_enabled, true))
      @pwa_short_name = Setting.fetch(:pwa_short_name, 'HomeChat')
      @pwa_theme_color = Setting.fetch(:pwa_theme_color, '#2563eb')
      @pwa_bg_color = Setting.fetch(:pwa_bg_color, '#ffffff')
      @pwa_display = Setting.fetch(:pwa_display, 'standalone')
      @litellm_host = Setting.fetch(:litellm_host, '')
      @litellm_default_model = Setting.fetch(:litellm_default_model, '')
      @litellm_api_key_present = Setting.fetch(:litellm_api_key, '').present?
      @litellm_models = []
      @litellm_error = nil

      if @litellm_host.present? && @litellm_api_key_present
        begin
          api_key = Setting.fetch(:litellm_api_key, nil)
          @litellm_models = LiteLlm::Client.new(host: @litellm_host, api_key: api_key).models
        rescue LiteLlm::Error => e
          @litellm_error = e.message
        end
      elsif @litellm_host.present?
        @litellm_error = 'LiteLLM API key is required to fetch models.'
      end
    end

    def update
      Setting.set(:site_name, params[:site_name].presence || 'HomeChat')
      Setting.set(:allow_signups, ActiveModel::Type::Boolean.new.cast(params[:allow_signups]))
      Setting.set(:pwa_enabled, ActiveModel::Type::Boolean.new.cast(params[:pwa_enabled]))
      Setting.set(:pwa_short_name, params[:pwa_short_name].presence || params[:site_name].presence || 'HomeChat')
      Setting.set(:pwa_theme_color, params[:pwa_theme_color].presence || '#2563eb')
      Setting.set(:pwa_bg_color, params[:pwa_bg_color].presence || '#ffffff')
      Setting.set(:pwa_display, params[:pwa_display].presence || 'standalone')
      litellm_host = params[:litellm_host].to_s.strip
      default_model = params[:litellm_default_model].to_s.strip
      if litellm_host.present?
        Setting.set(:litellm_host, litellm_host)
      else
        Setting.where(key: 'litellm_host').delete_all
      end

      if default_model.present?
        Setting.set(:litellm_default_model, default_model)
      else
        Setting.where(key: 'litellm_default_model').delete_all
      end

      if ActiveModel::Type::Boolean.new.cast(params[:reset_litellm_api_key])
        Setting.where(key: 'litellm_api_key').delete_all
      elsif params[:litellm_api_key].present?
        Setting.set(:litellm_api_key, params[:litellm_api_key].to_s.strip)
      end

      api_key = Setting.fetch(:litellm_api_key, nil)
      if litellm_host.present?
        if api_key.blank?
          redirect_to edit_admin_settings_path, alert: 'Settings saved. Add a LiteLLM API key to validate the connection.' and return
        else
          begin
            LiteLlm::Client.new(host: litellm_host, api_key: api_key).models
          rescue LiteLlm::Error => e
            redirect_to edit_admin_settings_path, alert: "Settings saved, but LiteLLM validation failed: #{e.message}" and return
          end
        end
      end

      redirect_to edit_admin_settings_path, notice: 'Server settings saved.'
    end

    private

    def ensure_admin!
      redirect_to dashboard_path, alert: 'Admins only.' unless current_user&.admin?
    end
  end
end
