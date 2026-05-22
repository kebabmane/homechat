class AddTokenExpiryAndNameToCompleteSignin < ActiveRecord::Migration[8.1]
  def change
    # expires_at column already exists on api_tokens — no schema change needed.
    # This migration is a no-op marker so we can track the feature deployment.
  end
end
