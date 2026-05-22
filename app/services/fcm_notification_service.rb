require "net/http"
require "json"
require "googleauth"

class FcmNotificationService
  FCM_SCOPE = "https://www.googleapis.com/auth/firebase.messaging".freeze
  FCM_API_URL = "https://fcm.googleapis.com/v1/projects/%s/messages:send".freeze

  class << self
    def send_message_notification(message, exclude_user: nil)
      return unless fcm_configured?

      # Get all users in the channel with FCM tokens, excluding the sender
      channel_users = message.channel.members
                             .where.not(fcm_token: nil)
                             .where.not(fcm_token: "")

      channel_users = channel_users.where.not(id: exclude_user.id) if exclude_user

      if channel_users.empty?
        Rails.logger.debug "FCM: No users with tokens found for channel_id=#{message.channel_id}"
        return
      end

      fcm_tokens = channel_users.pluck(:fcm_token)

      notification_data = {
        title: "HomeChat",
        body: "New message",
        data: {
          type: "message",
          channel_id: message.channel_id,
          message_id: message.id,
          notification_privacy: "generic"
        }
      }

      send_to_tokens(fcm_tokens, notification_data)
    end

    def send_channel_invite_notification(user, channel, inviter)
      return unless fcm_configured?
      return if user.fcm_token.blank?

      notification_data = {
        title: "HomeChat",
        body: "New invitation",
        data: {
          type: "channel_invite",
          notification_privacy: "generic"
        }
      }

      send_to_tokens([ user.fcm_token ], notification_data)
    end

    def send_direct_message_notification(message, recipient)
      return unless fcm_configured?
      return if recipient.fcm_token.blank?

      notification_data = {
        title: "HomeChat",
        body: "New direct message",
        data: {
          type: "message",
          channel_id: message.channel_id,
          message_id: message.id,
          notification_privacy: "generic"
        }
      }

      send_to_tokens([ recipient.fcm_token ], notification_data)
    end

    def send_mention_notification(message, mentioned_user)
      return unless fcm_configured?
      return if mentioned_user.fcm_token.blank?

      notification_data = {
        title: "HomeChat",
        body: "New mention",
        data: {
          type: "message",
          channel_id: message.channel_id,
          message_id: message.id,
          notification_privacy: "generic"
        }
      }

      send_to_tokens([ mentioned_user.fcm_token ], notification_data)
    end

    def fcm_configured?
      project_id.present? && credentials_available?
    end

    private

    def send_to_tokens(tokens, notification_data)
      return if tokens.empty?

      tokens.each do |token|
        send_single_notification(token, notification_data)
      end
    end

    def send_single_notification(token, notification_data)
      message_payload = build_message_payload(token, notification_data)

      uri = URI(format(FCM_API_URL, project_id))
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      http.open_timeout = 10
      http.read_timeout = 10

      request = Net::HTTP::Post.new(uri)
      request["Authorization"] = "Bearer #{access_token}"
      request["Content-Type"] = "application/json"
      request.body = { message: message_payload }.to_json

      response = http.request(request)

      case response.code.to_i
      when 200
        Rails.logger.info "FCM: Notification sent successfully"
      when 400
        Rails.logger.error "FCM: Invalid request"
      when 401
        Rails.logger.error "FCM: Authentication failed - check service account credentials"
        @access_token = nil # Force token refresh
      when 404
        # Token is invalid/unregistered - remove it from user
        Rails.logger.warn "FCM: Token invalid, removing from user"
        remove_invalid_token(token)
      when 429
        Rails.logger.warn "FCM: Rate limited, will retry later"
      else
        Rails.logger.error "FCM: Unexpected response #{response.code}"
      end
    rescue StandardError => e
      Rails.logger.error "FCM: Error sending notification - #{e.class}"
      Rails.logger.error e.backtrace.first(5).join("\n")
    end

    def build_message_payload(token, notification_data)
      {
        token: token,
        notification: {
          title: notification_data[:title],
          body: notification_data[:body]
        },
        data: notification_data[:data].transform_values(&:to_s),
        android: {
          priority: "high",
          notification: {
            sound: "default",
            click_action: "OPEN_CHANNEL"
          }
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
              badge: 1,
              'mutable-content': 1
            }
          }
        }
      }
    end

    def access_token
      @access_token ||= fetch_access_token
      @access_token
    end

    def fetch_access_token
      credentials = Google::Auth::ServiceAccountCredentials.make_creds(
        json_key_io: StringIO.new(service_account_json),
        scope: FCM_SCOPE
      )
      credentials.fetch_access_token!["access_token"]
    rescue StandardError => e
      Rails.logger.error "FCM: Failed to get access token - #{e.class}"
      nil
    end

    def project_id
      @project_id ||= fcm_config["project_id"]
    end

    def service_account_json
      @service_account_json ||= fcm_config["service_account_json"]&.to_json
    end

    def credentials_available?
      service_account_json.present?
    end

    def fcm_config
      @fcm_config ||= begin
        config = Rails.application.credentials.fcm || {}

        # Also check environment variables as fallback
        if config.empty?
          project_id = ENV["FCM_PROJECT_ID"]
          service_account = ENV["FCM_SERVICE_ACCOUNT_JSON"]

          if project_id.present? && service_account.present?
            config = {
              "project_id" => project_id,
              "service_account_json" => JSON.parse(service_account)
            }
          end
        end

        config.with_indifferent_access
      end
    end

    def remove_invalid_token(token)
      User.where(fcm_token: token).update_all(fcm_token: nil)
    end

    def truncate_message(content, length = 100)
      if content.length > length
        "#{content[0..length - 4]}..."
      else
        content
      end
    end
  end
end
