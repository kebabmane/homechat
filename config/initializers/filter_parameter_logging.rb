# Be sure to restart your server when you modify this file.

# Configure parameters to be partially matched (e.g. passw matches password) and filtered from the log file.
# Use this to limit dissemination of sensitive information.
# See the ActiveSupport::ParameterFilter documentation for supported notations and behaviors.
Rails.application.config.filter_parameters += [
  :passw, :email, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn, :cvv, :cvc,
  :authorization, :cookie, :message, :content, :body, :payload, :caption, :title, :sender,
  :encrypted_content, :content_hmac, :sender_key_fingerprint, :device_id, :signature,
  :channel_key, :encrypted_channel_key, :fcm_token, :username, :room_id, :filename
]
