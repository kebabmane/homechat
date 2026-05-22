class SystemDataWipeService
  def self.call(actor:, request: nil)
    new(actor: actor, request: request).call
  end

  def initialize(actor:, request: nil)
    @actor = actor
    @request = request
  end

  def call
    ActionCable.server.broadcast("presence", { type: "server_nuke" })

    ActiveRecord::Base.transaction do
      ActiveStorage::Attachment.joins(:blob).destroy_all
      ActiveStorage::Blob.all.find_each(&:purge)
      MessageReceipt.delete_all
      ChannelMembership.delete_all
      ChannelKeyShare.delete_all
      UserE2eeKey.delete_all
      UserKey.delete_all
      Message.delete_all
      Channel.delete_all
      User.update_all(fcm_token: nil)
    end

    AuditLog.log(
      action: "admin.nuke",
      user: @actor,
      ip_address: @request&.remote_ip,
      user_agent: @request&.user_agent
    )
  end
end
