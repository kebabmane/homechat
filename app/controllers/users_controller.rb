class UsersController < ApplicationController
  layout 'authentication'
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
