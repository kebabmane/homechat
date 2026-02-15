# frozen_string_literal: true

# Represents a token's access to a specific channel with a permission level.
# This enables channel-scoped API tokens that can only access specific channels.
class TokenChannelAssignment < ApplicationRecord
  belongs_to :api_token
  belongs_to :channel

  PERMISSIONS = %w[read write manage].freeze

  validates :permission, presence: true, inclusion: { in: PERMISSIONS }
  validates :channel_id, uniqueness: { scope: :api_token_id, message: 'already assigned to this token' }

  # Permission hierarchy helpers
  def can_read?
    true # Any assignment grants read access
  end

  def can_write?
    %w[write manage].include?(permission)
  end

  def can_manage?
    permission == 'manage'
  end
end
