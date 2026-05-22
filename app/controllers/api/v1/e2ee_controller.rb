class Api::V1::E2eeController < Api::V1::BaseController
  before_action :find_channel

  # POST /api/v1/channels/:id/rotate_key
  # Flags a channel for key rotation. All clients will detect this on the next channel open,
  # clear their local key, generate and distribute a new one, then acknowledge via this endpoint.
  def rotate_channel_key
    unless @channel.member?(current_api_user) || current_api_user.admin?
      return render json: { success: false, error: "forbidden" }, status: :forbidden
    end

    @channel.update!(
      key_rotation_required: true,
      key_epoch: @channel.key_epoch + 1
    )

    Rails.logger.info "E2EE key rotation requested for channel #{@channel.id} by user #{current_api_user.id}"

    render json: {
      success: true,
      key_epoch: @channel.key_epoch,
      rotation_required: @channel.key_rotation_required
    }, status: :ok
  end

  # GET /api/v1/channels/:id/key_rotation_status
  # Returns the current key rotation status for the channel.
  def key_rotation_status
    unless @channel.member?(current_api_user) || @channel.public?
      return render json: { success: false, error: "forbidden" }, status: :forbidden
    end

    render json: {
      rotation_required: @channel.key_rotation_required,
      epoch: @channel.key_epoch
    }, status: :ok
  end

  # POST /api/v1/channels/:id/acknowledge_rotation
  # Called by a client after it has generated and distributed the new key.
  # Clears the rotation_required flag once all members have acknowledged (simplified: first acker clears).
  def acknowledge_rotation
    unless @channel.member?(current_api_user)
      return render json: { success: false, error: "forbidden" }, status: :forbidden
    end

    @channel.update!(key_rotation_required: false)
    Rails.logger.info "E2EE key rotation acknowledged for channel #{@channel.id} by user #{current_api_user.id}"

    render json: { success: true }, status: :ok
  end

  private

  def find_channel
    @channel = Channel.find_by(id: params[:id])
    render json: { success: false, error: "channel_not_found" }, status: :not_found unless @channel
  end
end
