require 'digest'

class Api::V1::KeysController < Api::V1::BaseController
  class KeyShareValidationError < StandardError; end

  before_action :require_non_bot_token

  # Allow session-authenticated browser requests for web E2EE flows.
  def allow_session_api_auth?
    true
  end

  # PUT /api/v1/me/e2ee_key
  # Upsert the current user's device-scoped E2EE key bundle.
  def publish_e2ee_key
    device_id = E2eePolicy.device_id_from(request:, params: params)
    encryption_public_key = params[:encryption_public_key].presence || params[:public_key]
    signing_public_key = params[:signing_public_key].presence || params[:public_key]
    key_fingerprint = params[:key_fingerprint].presence || fingerprint_for(encryption_public_key, signing_public_key)
    key_version = params[:key_version].presence || '1'

    if !E2eePolicy.valid_device_id?(device_id) || encryption_public_key.blank? || signing_public_key.blank? || key_fingerprint.blank?
      return render json: { success: false, error: 'device_id, encryption_public_key, signing_public_key and key_fingerprint are required' }, status: :unprocessable_entity
    end

    key_record = UserE2eeKey.find_or_initialize_by(user_id: current_api_user.id, device_id: device_id)
    key_rotated = key_record.persisted? && key_record.key_fingerprint.present? && key_record.key_fingerprint != key_fingerprint

    key_record.assign_attributes(
      encryption_public_key: encryption_public_key,
      signing_public_key: signing_public_key,
      public_key: encryption_public_key,
      key_fingerprint: key_fingerprint,
      key_version: key_version,
      last_seen_at: Time.current,
      revoked_at: nil
    )

    key_record.first_published_at ||= Time.current
    if key_rotated
      key_record.rotation_count = key_record.rotation_count.to_i + 1
      key_record.last_rotated_at = Time.current
    end

    if key_record.save
      render json: serialize_device_key(key_record), status: :ok
    else
      render json: { success: false, errors: key_record.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # GET /api/v1/users/:id/e2ee_key
  # Retrieve active E2EE device keys for a given user.
  def get_user_e2ee_key
    key_records = UserE2eeKey.where(user_id: params[:id], revoked_at: nil).order(updated_at: :desc)

    if key_records.blank?
      return render json: { success: false, error: 'E2EE key not found for this user' }, status: :not_found
    end

    render json: {
      user_id: params[:id].to_i,
      devices: key_records.map { |k| serialize_device_key(k) }
    }, status: :ok
  end

  # GET /api/v1/channels/:id/e2ee_keys
  # Returns active device key bundles for all channel members.
  def get_channel_e2ee_keys
    channel = Channel.find_by(id: params[:id])

    unless channel
      return render json: { success: false, error: 'Channel not found' }, status: :not_found
    end

    unless channel.accessible_by?(current_api_user)
      return render json: { success: false, error: 'Forbidden - You do not have access to this channel' }, status: :forbidden
    end

    member_keys = UserE2eeKey
                    .joins(:user)
                    .joins("INNER JOIN channel_memberships ON channel_memberships.user_id = user_e2ee_keys.user_id AND channel_memberships.channel_id = #{channel.id.to_i}")
                    .where(revoked_at: nil)
                    .order('users.username ASC, user_e2ee_keys.updated_at DESC')

    members = member_keys.map do |mk|
      {
        user_id: mk.user_id,
        username: mk.user.username,
        device_id: mk.device_id,
        encryption_public_key: mk.encryption_public_key,
        signing_public_key: mk.signing_public_key,
        key_fingerprint: mk.key_fingerprint,
        key_version: mk.key_version,
        rotation_count: mk.rotation_count,
        first_published_at: mk.first_published_at&.iso8601,
        last_rotated_at: mk.last_rotated_at&.iso8601,
        published_at: mk.published_at&.iso8601,
        last_seen_at: mk.last_seen_at&.iso8601
      }
    end

    render json: { channel_id: channel.id, members: members }, status: :ok
  end

  # POST /api/v1/channels/:id/key_shares
  # Accept signed encrypted channel key shares for multiple recipient devices.
  def submit_key_shares
    channel = Channel.find_by(id: params[:id])

    unless channel
      return render json: { success: false, error: 'Channel not found' }, status: :not_found
    end

    unless channel.accessible_by?(current_api_user)
      return render json: { success: false, error: 'Forbidden - You do not have access to this channel' }, status: :forbidden
    end

    sender_device_id = E2eePolicy.device_id_from(request:, params: params)
    sender_key = UserE2eeKey.find_by(user_id: current_api_user.id, device_id: sender_device_id, revoked_at: nil)

    unless sender_key
      return render json: { success: false, error: 'Sender device key not found or inactive' }, status: :unprocessable_entity
    end

    raw_shares = params[:key_shares]

    shares_list = case raw_shares
                  when ActionController::Parameters
                    raw_shares.values
                  when Array
                    raw_shares
                  else
                    []
                  end

    shares_list = shares_list.select { |s| s.is_a?(Hash) || s.is_a?(ActionController::Parameters) }

    if shares_list.blank?
      return render json: { success: false, error: 'key_shares must be a non-empty array' }, status: :unprocessable_entity
    end

    created_count = 0

    ActiveRecord::Base.transaction do
      shares_list.each do |share|
        share = share.respond_to?(:to_unsafe_h) ? share.to_unsafe_h.with_indifferent_access : share.with_indifferent_access
        recipient_user_id = share[:recipient_user_id].to_i
        recipient_device_id = share[:recipient_device_id].to_s
        encrypted_channel_key = share[:encrypted_channel_key]
        signature = share[:signature]
        sender_share_device_id = share[:sender_device_id].presence || sender_device_id
        sender_key_fingerprint = share[:sender_key_fingerprint].presence || sender_key.key_fingerprint
        key_version = share[:key_version].presence || '1'

        if recipient_user_id.zero? || recipient_device_id.blank? || encrypted_channel_key.blank? || signature.blank?
          raise KeyShareValidationError, 'Each share must include recipient_user_id, recipient_device_id, encrypted_channel_key, and signature'
        end

        unless sender_share_device_id == sender_device_id && sender_key_fingerprint == sender_key.key_fingerprint
          raise KeyShareValidationError, 'sender_device_id and sender_key_fingerprint must match your active device key'
        end

        unless channel.channel_memberships.exists?(user_id: recipient_user_id)
          raise KeyShareValidationError, 'recipient_user_id must be a current member of the channel'
        end

        recipient_key = UserE2eeKey.find_by(user_id: recipient_user_id, device_id: recipient_device_id, revoked_at: nil)
        unless recipient_key
          raise KeyShareValidationError, 'recipient_device_id must belong to an active channel member device key'
        end

        key_share = ChannelKeyShare.find_or_initialize_by(
          channel_id: channel.id,
          recipient_user_id: recipient_user_id,
          recipient_device_id: recipient_device_id
        )

        if key_share.persisted? && key_share.sender_user_id != current_api_user.id
          raise KeyShareValidationError, 'Only the original sender may overwrite an existing key share for this recipient device'
        end

        key_share.assign_attributes(
          sender_user_id: current_api_user.id,
          sender_device_id: sender_device_id,
          sender_key_fingerprint: sender_key_fingerprint,
          encrypted_channel_key: encrypted_channel_key,
          signature: signature,
          key_version: key_version
        )

        key_share.save!
        created_count += 1
      end
    end

    render json: { success: true, created: created_count }, status: :ok
  rescue ActiveRecord::RecordInvalid => e
    render json: { success: false, error: e.message }, status: :unprocessable_entity
  rescue KeyShareValidationError => e
    render json: { success: false, error: e.message }, status: :unprocessable_entity
  end

  # GET /api/v1/channels/:id/key_shares/me
  # Retrieve the encrypted channel key share destined for the current user's device.
  def get_my_key_share
    channel = Channel.find_by(id: params[:id])

    unless channel
      return render json: { success: false, error: 'Channel not found' }, status: :not_found
    end

    unless channel.accessible_by?(current_api_user)
      return render json: { success: false, error: 'Forbidden - You do not have access to this channel' }, status: :forbidden
    end

    recipient_device_id = E2eePolicy.device_id_from(request:, params: params)
    unless E2eePolicy.valid_device_id?(recipient_device_id)
      return render json: { success: false, error: 'A valid device_id is required' }, status: :unprocessable_entity
    end

    key_share = ChannelKeyShare.find_by(
      channel_id: channel.id,
      recipient_user_id: current_api_user.id,
      recipient_device_id: recipient_device_id
    )

    unless key_share
      return render json: { success: false, error: 'No key share found for this channel/device' }, status: :not_found
    end

    render json: {
      encrypted_channel_key: key_share.encrypted_channel_key,
      signature: key_share.signature,
      sender_user_id: key_share.sender_user_id,
      sender_device_id: key_share.sender_device_id,
      sender_key_fingerprint: key_share.sender_key_fingerprint,
      recipient_device_id: key_share.recipient_device_id,
      key_version: key_share.key_version
    }, status: :ok
  end

  private

  def serialize_device_key(key_record)
    {
      user_id: key_record.user_id,
      device_id: key_record.device_id,
      encryption_public_key: key_record.encryption_public_key,
      signing_public_key: key_record.signing_public_key,
      key_fingerprint: key_record.key_fingerprint,
      key_version: key_record.key_version,
      rotation_count: key_record.rotation_count,
      first_published_at: key_record.first_published_at&.iso8601,
      last_rotated_at: key_record.last_rotated_at&.iso8601,
      published_at: key_record.published_at&.iso8601,
      last_seen_at: key_record.last_seen_at&.iso8601
    }
  end

  def fingerprint_for(encryption_public_key, signing_public_key)
    Digest::SHA256.hexdigest("#{encryption_public_key}|#{signing_public_key}")
  end
end
