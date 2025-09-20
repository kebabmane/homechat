class UsersController < ApplicationController
  layout 'authentication'
  before_action :require_login, only: [:search]

  def search
    query = params[:q]&.strip

    if query.blank? || query.length < 2
      render json: []
      return
    end

    users = User.where('LOWER(username) LIKE LOWER(?)', "%#{query}%")
                .where.not(id: current_user.id)
                .limit(10)
                .map do |user|
      {
        id: user.id,
        username: user.username,
        is_online: user.online?
      }
    end

    render json: users
  end

  def new
    if !ActiveModel::Type::Boolean.new.cast(Setting.fetch(:allow_signups, true))
      redirect_to signin_path, alert: 'Sign ups are disabled by the administrator.' and return
    end
    @user = User.new
  end

  def create
    if !ActiveModel::Type::Boolean.new.cast(Setting.fetch(:allow_signups, true))
      redirect_to signin_path, alert: 'Sign ups are disabled by the administrator.' and return
    end
    @user = User.new(user_params)
    # Bootstrap: first user becomes admin automatically
    @user.role = 'admin' if User.count == 0
    
    if @user.save
      session[:user_id] = @user.id
      redirect_to dashboard_path, notice: 'Account created successfully!'
    else
      render :new, status: :unprocessable_content
    end
  end
  
  private
  
  def user_params
    params.require(:user).permit(:username, :password, :password_confirmation)
  end
end
