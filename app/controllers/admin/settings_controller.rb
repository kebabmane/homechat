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
    end

    def update
      Setting.set(:site_name, params[:site_name].presence || 'HomeChat')
      Setting.set(:allow_signups, ActiveModel::Type::Boolean.new.cast(params[:allow_signups]))
      Setting.set(:pwa_enabled, ActiveModel::Type::Boolean.new.cast(params[:pwa_enabled]))
      Setting.set(:pwa_short_name, params[:pwa_short_name].presence || params[:site_name].presence || 'HomeChat')
      Setting.set(:pwa_theme_color, params[:pwa_theme_color].presence || '#2563eb')
      Setting.set(:pwa_bg_color, params[:pwa_bg_color].presence || '#ffffff')
      Setting.set(:pwa_display, params[:pwa_display].presence || 'standalone')
      redirect_to edit_admin_settings_path, notice: 'Server settings saved.'
    end

    private

    def ensure_admin!
      redirect_to dashboard_path, alert: 'Admins only.' unless current_user&.admin?
    end
  end
end
