module Admin
  class BotsController < ApplicationController
    include Auditable

    before_action :require_admin
    before_action :set_bot, only: [:show, :edit, :update, :activate, :deactivate, :destroy, :regenerate_secret]
    before_action :load_models, only: [:new, :create, :edit, :update]

    def index
      @bots = Bot.order(:name)
      @tokens = ApiToken.order(created_at: :desc)
      @new_token = ApiToken.new
    end

    def new
      @bot = Bot.new(bot_type: params[:bot_type].presence || 'ai', active: true)
    end

    def create
      @bot = Bot.new(bot_params)
      if @bot.save
        audit_create(@bot)
        redirect_to admin_bot_path(@bot), notice: 'Bot created successfully.'
      else
        render :new, status: :unprocessable_entity
      end
    end

    def show
      # Show bot details including webhook URL and secret
    end

    def edit
      unless @bot.ai_bot?
        redirect_to admin_bot_path(@bot), alert: 'Only AI bots can be edited via this screen.'
        return
      end
    end

    def update
      unless @bot.ai_bot?
        redirect_to admin_bot_path(@bot), alert: 'Only AI bots can be updated via this screen.'
        return
      end

      if @bot.update(bot_params)
        audit_update(@bot)
        redirect_to admin_bot_path(@bot), notice: 'Bot updated successfully.'
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def regenerate_secret
      if @bot.webhook?
        @bot.regenerate_webhook_secret!
        audit_log(AuditLog::ACTIONS[:token_regenerated], resource: @bot)
        redirect_to admin_bot_path(@bot), notice: 'Webhook secret regenerated successfully.'
      else
        redirect_to admin_bots_path, alert: 'Only webhook bots have secrets.'
      end
    end

    def activate
      @bot.activate!
      audit_log(AuditLog::ACTIONS[:bot_activated], resource: @bot)
      redirect_to admin_bots_path, notice: 'Bot activated.'
    end

    def deactivate
      @bot.deactivate!
      audit_log(AuditLog::ACTIONS[:bot_deactivated], resource: @bot)
      redirect_to admin_bots_path, notice: 'Bot deactivated.'
    end

    def destroy
      audit_destroy(@bot)
      @bot.destroy
      redirect_to admin_bots_path, notice: 'Bot deleted.'
    end

    private

    def set_bot
      @bot = Bot.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      redirect_to admin_bots_path, alert: 'Bot not found.'
    end

    def bot_params
      params.require(:bot).permit(:name, :description, :bot_type, :instructions, :model, :active)
    end

    def load_models
      @available_models = []
      @models_error = nil

      target_type = @bot&.bot_type || params.dig(:bot, :bot_type)
      return unless target_type.blank? || target_type.to_s == 'ai'

      host = Setting.fetch(:litellm_host, '')
      return if host.blank?

      api_key = Setting.fetch(:litellm_api_key, '')
      if api_key.blank?
        @models_error = 'LiteLLM API key is required to fetch models.'
        return
      end

      begin
        @available_models = LiteLlm::Client.new(host: host, api_key: api_key).models
      rescue LiteLlm::Error => e
        @models_error = e.message
      end
    end
  end
end
