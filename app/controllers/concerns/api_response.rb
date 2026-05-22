# frozen_string_literal: true

# Provides consistent API response formatting across all API controllers.
#
# Standard response format:
#   Success: { success: true, <resource_key>: <data>, message?: <string> }
#   Error:   { success: false, error: <string> } or { success: false, errors: [<strings>] }
#
# Collection responses include pagination metadata:
#   { success: true, <collection_key>: [...], meta: { total: n, has_more: bool } }
#
module ApiResponse
  extend ActiveSupport::Concern

  included do
    # Define standard HTTP status mappings
    HTTP_STATUS_MAP = {
      success: :ok,
      created: :created,
      accepted: :accepted,
      no_content: :no_content,
      bad_request: :bad_request,
      unauthorized: :unauthorized,
      forbidden: :forbidden,
      not_found: :not_found,
      unprocessable_entity: :unprocessable_entity,
      internal_server_error: :internal_server_error
    }.freeze
  end

  # Render a successful response with a single resource
  #
  # @param resource_key [Symbol, String] The key name for the resource (e.g., :user, :channel)
  # @param data [Hash, Object] The resource data
  # @param message [String, nil] Optional success message
  # @param status [Symbol] HTTP status (default: :ok)
  #
  # Example:
  #   render_resource(:user, { id: 1, username: 'alice' })
  #   # => { success: true, user: { id: 1, username: 'alice' } }
  #
  def render_resource(resource_key, data, message: nil, status: :ok)
    response = { success: true, resource_key => data }
    response[:message] = message if message.present?
    render json: response, status: status
  end

  # Render a successful response with a collection of resources
  #
  # @param collection_key [Symbol, String] The key name for the collection (e.g., :users, :channels)
  # @param data [Array] The collection data
  # @param meta [Hash] Optional metadata (total, has_more, page, per_page)
  # @param status [Symbol] HTTP status (default: :ok)
  #
  # Example:
  #   render_collection(:channels, channels_array, meta: { total: 10, has_more: true })
  #   # => { success: true, channels: [...], meta: { total: 10, has_more: true } }
  #
  def render_collection(collection_key, data, meta: nil, status: :ok)
    response = { success: true, collection_key => data }
    response[:meta] = meta if meta.present?
    render json: response, status: status
  end

  # Render a simple success response (for actions like join, leave, delete)
  #
  # @param message [String] Success message
  # @param data [Hash] Optional additional data
  # @param status [Symbol] HTTP status (default: :ok)
  #
  # Example:
  #   render_success_message('Successfully joined channel')
  #   # => { success: true, message: 'Successfully joined channel' }
  #
  def render_success_message(message, data: {}, status: :ok)
    response = { success: true, message: message }
    response.merge!(data) unless data.empty?
    render json: response, status: status
  end

  # Render an error response with a single error message
  #
  # @param message [String] Error message
  # @param status [Symbol] HTTP status (default: :bad_request)
  # @param code [String, nil] Optional error code for client handling
  #
  # Example:
  #   render_api_error('Channel not found', status: :not_found)
  #   # => { success: false, error: 'Channel not found' }
  #
  def render_api_error(message, status: :bad_request, code: nil)
    response = { success: false, error: message }
    response[:code] = code if code.present?
    render json: response, status: status
  end

  # Render an error response with multiple error messages (e.g., validation errors)
  #
  # @param errors [Array<String>] Array of error messages
  # @param status [Symbol] HTTP status (default: :unprocessable_entity)
  #
  # Example:
  #   render_validation_errors(user.errors.full_messages)
  #   # => { success: false, errors: ['Username is required', 'Password is too short'] }
  #
  def render_validation_errors(errors, status: :unprocessable_entity)
    render json: { success: false, errors: Array(errors) }, status: status
  end

  # Render an error response from an ActiveRecord model's errors
  #
  # @param model [ActiveRecord::Base] The model with errors
  # @param status [Symbol] HTTP status (default: :unprocessable_entity)
  #
  def render_model_errors(model, status: :unprocessable_entity)
    render_validation_errors(model.errors.full_messages, status: status)
  end

  # Render a not found error
  #
  # @param resource_name [String] Name of the resource that wasn't found
  #
  def render_not_found(resource_name = "Resource")
    render_api_error("#{resource_name} not found", status: :not_found, code: "not_found")
  end

  # Render an unauthorized error
  #
  # @param message [String] Error message (default: 'Unauthorized')
  #
  def render_unauthorized(message = "Unauthorized")
    render_api_error(message, status: :unauthorized, code: "unauthorized")
  end

  # Render a forbidden error
  #
  # @param message [String] Error message (default: 'Forbidden')
  #
  def render_forbidden(message = "Forbidden")
    render_api_error(message, status: :forbidden, code: "forbidden")
  end

  # Helper to wrap legacy bare object responses in standard envelope
  # Use this when migrating existing endpoints
  #
  # @param data [Hash] The data to wrap
  # @param status [Symbol] HTTP status (default: :ok)
  #
  def render_data(data, status: :ok)
    render json: { success: true }.merge(data), status: status
  end

  # Helper for paginated collection responses
  #
  # @param collection_key [Symbol] The key for the collection
  # @param items [Array] The items in this page
  # @param total [Integer, nil] Total count (if known)
  # @param has_more [Boolean] Whether more items exist
  # @param page [Integer, nil] Current page number
  # @param per_page [Integer, nil] Items per page
  #
  def render_paginated(collection_key, items, total: nil, has_more: false, page: nil, per_page: nil)
    meta = { has_more: has_more }
    meta[:total] = total if total.present?
    meta[:page] = page if page.present?
    meta[:per_page] = per_page if per_page.present?

    response = { success: true, collection_key => items, has_more: has_more, meta: meta }
    render json: response, status: :ok
  end
end
