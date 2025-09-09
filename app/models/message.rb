class Message < ApplicationRecord
  include ActionView::RecordIdentifier
  belongs_to :user
  belongs_to :channel
  has_many_attached :files

  validates :content, presence: true, length: { minimum: 1, maximum: 2000 }
  
  scope :recent, -> { order(created_at: :desc) }
  scope :for_channel, ->(channel) { where(channel: channel) }
  
  def author_name
    user.username
  end

  after_create_commit -> { broadcast_append }

  private

  def broadcast_append
    broadcast_append_to channel,
      target: dom_id(channel, :messages),
      partial: "messages/message",
      locals: { message: self }
  end
end
