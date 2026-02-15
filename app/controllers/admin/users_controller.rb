module Admin
  class UsersController < ApplicationController
    before_action :require_login
    before_action :ensure_admin!
    before_action :set_user, only: [:update, :approve, :reject, :generate_reset_link]

    def index
      @users = User.select(
        'users.*',
        '(SELECT COUNT(*) FROM messages WHERE messages.user_id = users.id) AS messages_count',
        '(SELECT COUNT(*) FROM channel_memberships WHERE channel_memberships.user_id = users.id) AS channels_count'
      ).order(:username)
      @admins_count = User.where(role: 'admin').count
      @pending_users = User.pending_approval
      @require_approval = Setting.fetch(:require_signup_approval, false)
    end

    def update
      new_role = params[:user][:role]
      unless %w[user admin].include?(new_role)
        redirect_to admin_users_path, alert: 'Invalid role' and return
      end

      if @user.role == 'admin' && new_role == 'user' && User.where(role: 'admin').count <= 1
        redirect_to admin_users_path, alert: 'Cannot demote the last admin.' and return
      end

      @user.update!(role: new_role)
      redirect_to admin_users_path, notice: "Updated #{@user.username} to #{new_role}."
    end

    def approve
      @user.approve!(current_user)
      redirect_to admin_users_path, notice: "#{@user.username} has been approved."
    end

    def reject
      username = @user.username
      @user.reject!
      redirect_to admin_users_path, notice: "#{username} has been rejected and removed."
    end

    def generate_reset_link
      raw_token = @user.generate_password_reset_token!
      @reset_url = password_reset_url(token: raw_token)

      AuditLog.log(
        action: 'admin.password_reset_generated',
        user: current_user,
        resource: @user,
        ip_address: request.remote_ip,
        user_agent: request.user_agent,
        metadata: { target_user: @user.username }
      )

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to admin_users_path, notice: "Reset link generated for #{@user.username}." }
      end
    end

    private

    def set_user
      @user = User.find(params[:id])
    end

    def ensure_admin!
      redirect_to dashboard_path, alert: 'Admins only.' unless current_user&.admin?
    end
  end
end

