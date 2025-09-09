class Api::V1::HealthController < Api::V1::BaseController
  skip_before_action :authenticate_api_request, only: [:show]
  
  def show
    render json: {
      status: 'ok',
      timestamp: Time.current.iso8601,
      version: '1.0.0',
      service: 'HomeChat'
    }
  end
end