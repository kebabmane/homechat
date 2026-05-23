class Api::V1::Admin::NukesController < Api::V1::BaseController
  before_action :require_admin_user

  def create
    unless params[:confirmation] == "NUKE"
      render_error("Type NUKE to confirm", :unprocessable_entity)
      return
    end

    SystemDataWipeService.call(actor: current_api_user, request: request)
    render_success({ message: "All data has been wiped", user_id: current_api_user.id })
  end

  private

  def require_admin_user
    return if current_api_user&.admin?

    render_error("Forbidden - Admins only", :forbidden)
  end
end
