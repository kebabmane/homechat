module Admin
  class TokensController < ApplicationController
    before_action :require_admin
    before_action :set_token, only: [ :edit, :update, :activate, :deactivate, :regenerate, :destroy ]

    def index
      redirect_to admin_bots_path(tab: "tokens")
    end

    def create
      @token = ApiToken.new(token_params.merge(active: true, user: current_user))

      if @token.save
        create_channel_assignments(@token)
        render :show_token
      else
        redirect_to admin_bots_path(tab: "tokens"), alert: @token.errors.full_messages.to_sentence
      end
    end

    def edit
      @channels = Channel.where.not(channel_type: "dm").order(:name)
      @token_assignments_by_channel_id = @token.token_channel_assignments.index_by(&:channel_id)
    end

    def update
      if @token.update(token_params)
        update_channel_assignments(@token)
        redirect_to admin_bots_path(tab: "tokens"), notice: "Token updated."
      else
        @channels = Channel.where.not(channel_type: "dm").order(:name)
        @token_assignments_by_channel_id = @token.token_channel_assignments.index_by(&:channel_id)
        render :edit, status: :unprocessable_entity
      end
    end

    def regenerate
      @token.regenerate!
      render :show_token
    end

    def activate
      @token.update!(active: true)
      redirect_to admin_bots_path(tab: "tokens"), notice: "Token activated."
    end

    def deactivate
      @token.update!(active: false)
      redirect_to admin_bots_path(tab: "tokens"), notice: "Token deactivated."
    end

    def destroy
      name = @token.name
      @token.destroy
      redirect_to admin_bots_path(tab: "tokens"), notice: "Token '#{name}' deleted."
    end

    private

    def set_token
      @token = ApiToken.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      redirect_to admin_tokens_path, alert: "Token not found."
    end

    def token_params
      params.require(:api_token).permit(:name, :token_type, :expires_at, scopes: [])
    end

    def create_channel_assignments(token)
      return if params[:channel_ids].blank?

      params[:channel_ids].each do |channel_id|
        next if channel_id.blank?
        permission = params.dig(:channel_permissions, channel_id) || "read"
        token.token_channel_assignments.create!(
          channel_id: channel_id,
          permission: permission
        )
      end
    end

    def update_channel_assignments(token)
      token.token_channel_assignments.destroy_all
      create_channel_assignments(token)
    end
  end
end
