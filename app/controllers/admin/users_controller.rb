module Admin
  class UsersController < ApplicationController
    before_action :require_login
    before_action :ensure_admin!

    def index
      @users = User.select(
        'users.*',
        '(SELECT COUNT(*) FROM messages WHERE messages.user_id = users.id) AS messages_count',
        '(SELECT COUNT(*) FROM channel_memberships WHERE channel_memberships.user_id = users.id) AS channels_count'
      ).order(:username)
      @admins_count = User.where(role: 'admin').count
    end

    def update
      user = User.find(params[:id])
      new_role = params[:user][:role]
      unless %w[user admin].include?(new_role)
        redirect_to admin_users_path, alert: 'Invalid role' and return
      end

      if user.role == 'admin' && new_role == 'user' && User.where(role: 'admin').count <= 1
        redirect_to admin_users_path, alert: 'Cannot demote the last admin.' and return
      end

      user.update!(role: new_role)
      redirect_to admin_users_path, notice: "Updated #{user.username} to #{new_role}."
    end

    private

    def ensure_admin!
      redirect_to dashboard_path, alert: 'Admins only.' unless current_user&.admin?
    end
  end
end

