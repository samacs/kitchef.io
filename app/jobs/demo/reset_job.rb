module Demo
  # Nightly reset for the shared public demo account
  # (`kitchef.mx/cocina-demo`). Wipes the noisy state customers + ops
  # generate during demos so the next call lands on a clean slate.
  #
  # Specifically clears:
  #   - pedidos placed during the demo
  #   - clients created via storefront / drawer
  #   - notifications
  #
  # Recipes, ingredients, schedule, account branding, and the comp-Pro
  # subscription are deliberately preserved — those are the demo's
  # "show me what's possible" surface and shouldn't be torn down.
  #
  # Idempotent: running it on an already-clean account is a no-op.
  class ResetJob < ApplicationJob
    queue_as :low

    DEMO_ACCOUNT_SLUG = "cocina-demo".freeze

    def perform(slug = DEMO_ACCOUNT_SLUG)
      account = Account.kept.find_by(slug: slug)
      return if account.nil?
      return unless account.demo?

      Rails.logger.info("[Demo::Reset] resetting #{account.slug}")

      account.orders.find_each(&:destroy!)
      account.clients.find_each(&:destroy!)

      Noticed::Notification
        .where(recipient: account.users)
        .destroy_all

      Subscriptions::DismissedHint.where(account: account).destroy_all

      Rails.logger.info("[Demo::Reset] done #{account.slug}")
    end
  end
end
