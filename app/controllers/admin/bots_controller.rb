module Admin
  class BotsController < ApplicationController
    before_action :require_admin
    before_action :set_bot, only: [:show, :activate, :deactivate, :destroy, :regenerate_secret]

    def index
      @bots = Bot.order(:name)
    end

    def show
      # Show bot details including webhook URL and secret
    end

    def regenerate_secret
      if @bot.webhook?
        @bot.regenerate_webhook_secret!
        redirect_to admin_bot_path(@bot), notice: 'Webhook secret regenerated successfully.'
      else
        redirect_to admin_bots_path, alert: 'Only webhook bots have secrets.'
      end
    end

    def activate
      @bot.activate!
      redirect_to admin_bots_path, notice: 'Bot activated.'
    end

    def deactivate
      @bot.deactivate!
      redirect_to admin_bots_path, notice: 'Bot deactivated.'
    end

    def destroy
      @bot.destroy
      redirect_to admin_bots_path, notice: 'Bot deleted.'
    end

    private

    def set_bot
      @bot = Bot.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      redirect_to admin_bots_path, alert: 'Bot not found.'
    end
  end
end

