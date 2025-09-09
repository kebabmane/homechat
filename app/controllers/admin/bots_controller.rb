module Admin
  class BotsController < ApplicationController
    before_action :require_admin
    before_action :set_bot, only: [:activate, :deactivate, :destroy]

    def index
      @bots = Bot.order(:name)
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

