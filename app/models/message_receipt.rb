class MessageReceipt < ApplicationRecord
  belongs_to :message
  belongs_to :user
  enum :status, { delivered: 0, read: 1 }
end
