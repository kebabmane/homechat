class Admin::NukesController < ApplicationController
  before_action :require_admin

  def show; end

  def create
    unless params[:confirmation] == "NUKE"
      redirect_to admin_nuke_path, alert: "Type NUKE to confirm."
      return
    end

    SystemDataWipeService.call(actor: current_user, request: request)

    redirect_to admin_dashboard_path, notice: "All data has been wiped."
  end
end
