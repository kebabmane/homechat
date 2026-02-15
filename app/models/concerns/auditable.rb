# Concern for adding audit logging to admin controllers
# Include in controllers that need audit logging

module Auditable
  extend ActiveSupport::Concern

  included do
    # Store request info for audit logging
    before_action :set_audit_context
  end

  private

  def set_audit_context
    @audit_context = {
      ip_address: request.remote_ip,
      user_agent: request.user_agent
    }
  end

  def audit_log(action, resource:, changes: nil, metadata: nil)
    AuditLog.log(
      action: action,
      user: current_user,
      resource: resource,
      ip_address: @audit_context[:ip_address],
      user_agent: @audit_context[:user_agent],
      changes: changes,
      metadata: metadata
    )
  end

  def audit_create(resource, metadata: nil)
    audit_log(
      "#{resource.class.name.underscore}.created",
      resource: resource,
      metadata: metadata
    )
  end

  def audit_update(resource, changes: nil, metadata: nil)
    audit_log(
      "#{resource.class.name.underscore}.updated",
      resource: resource,
      changes: changes || resource.saved_changes.except(:updated_at),
      metadata: metadata
    )
  end

  def audit_destroy(resource, metadata: nil)
    audit_log(
      "#{resource.class.name.underscore}.deleted",
      resource: resource,
      metadata: metadata&.merge(deleted_attributes: resource.attributes.except("password_digest"))
    )
  end
end
