module Admin
  class TokensController < ApplicationController
    before_action :require_admin
    before_action :set_token, only: [:activate, :deactivate, :regenerate, :destroy]

    def index
      @tokens = ApiToken.order(:name)
      @new_token = ApiToken.new
    end

    def create
      @token = ApiToken.new(token_params.merge(active: true))

      if @token.save
        # Return the modal content with the token
        render :show_token
      else
        @tokens = ApiToken.order(:name)
        @new_token = @token
        flash.now[:alert] = @token.errors.full_messages.to_sentence
        render :index
      end
    end

    def regenerate
      @token.regenerate!
      render :show_token
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

    def token_params
      params.require(:api_token).permit(:name)
    end
  end
end

