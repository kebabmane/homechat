class SessionsController < ApplicationController
  layout 'authentication'
  def new
  end

  def create
    user = User.find_by(username: params[:username])
    
    if user && user.authenticate(params[:password])
      session[:user_id] = user.id
      redirect_to dashboard_path, notice: 'Signed in successfully!'
    else
      flash.now[:alert] = 'Invalid username or password'
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    session[:user_id] = nil
    redirect_to root_path, notice: 'Signed out successfully!'
  end
end
