module Admin
  class TokensController < ApplicationController
    before_action :require_admin
    before_action :set_token, only: [:activate, :deactivate, :regenerate, :destroy]

    def index
      @tokens = ApiToken.order(:name)
      @new_token = ApiToken.new
    end

    def create
      token = ApiToken.create!(name: params[:api_token][:name], active: true)
      redirect_to admin_tokens_path, notice: "Token created: #{token.masked_token}"
    rescue ActiveRecord::RecordInvalid => e
      redirect_to admin_tokens_path, alert: e.record.errors.full_messages.to_sentence
    end

    def regenerate
      @token.regenerate!
      redirect_to admin_tokens_path, notice: "Token regenerated: #{@token.masked_token}"
    end

    def activate
      @token.update!(active: true)
      redirect_to admin_tokens_path, notice: 'Token activated.'
    end

    def deactivate
      @token.update!(active: false)
      redirect_to admin_tokens_path, notice: 'Token deactivated.'
    end

    def destroy
      name = @token.name
      @token.destroy
      redirect_to admin_tokens_path, notice: "Token '#{name}' deleted."
    end

    private

    def set_token
      @token = ApiToken.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      redirect_to admin_tokens_path, alert: 'Token not found.'
    end
  end
end

