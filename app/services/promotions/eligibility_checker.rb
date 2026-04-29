module Promotions
  class EligibilityChecker < ApplicationService
    option :account
    option :subtotal_cents
    option :client, default: -> { nil }
    option :kind, default: -> { nil }

    def call
      scope = account.promotions.active_now
      scope = scope.where(kind: kind) if kind.present?
      scope.by_priority.select { |p| p.eligible?(subtotal_cents: subtotal_cents, client: client) }
    end
  end
end
