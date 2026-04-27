module Subscriptions
  # Per-account dismissal record for upgrade-hint banners. When an
  # operator closes a hint, we write a row here so the same hint
  # doesn't reappear on every device-switch. A future-dated
  # `redismiss_at` lets a hint resurface (e.g., monthly pedidos
  # reset re-arms the "you used 35/40" banner).
  #
  # Hint keys are bare strings — defined wherever the banner is
  # rendered, namespaced with a `:` (e.g. `pedidos:approaching_limit`,
  # `recipes:try_decomposition`, `reports:locked`). No central
  # registry; the dismiss controller accepts any non-blank key.
  class DismissedHint < ApplicationRecord
    self.table_name = "subscriptions_dismissed_hints"

    belongs_to :account

    validates :hint_key,     presence: true, length: { maximum: 80 }
    validates :hint_key,     uniqueness: { scope: :account_id }
    validates :dismissed_at, presence: true

    # Returns the row that's still suppressing the hint, or nil if
    # the operator hasn't dismissed it (or her dismissal expired).
    def self.active_for(account:, hint_key:)
      where(account: account, hint_key: hint_key)
        .where("redismiss_at IS NULL OR redismiss_at > ?", Time.current)
        .first
    end

    def self.dismissed?(account:, hint_key:)
      active_for(account: account, hint_key: hint_key).present?
    end
  end
end
