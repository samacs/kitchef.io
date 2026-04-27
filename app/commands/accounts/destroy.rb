module Accounts
  # Hard-delete an account and everything under it. Caller must have
  # already confirmed the kitchen name matches; this command does NOT
  # re-confirm — callers compose with that check themselves so this
  # stays composable from the admin tooling too.
  #
  # Cascade order is enforced by `Account.has_many` declaration order
  # (see CLAUDE.md gotchas — orders before recipes/ingredients
  # because OrderItem FK-references Recipe). Soft-delete is bypassed
  # via `destroy` (not `discard`) so the row physically vanishes.
  #
  # Stripe-side cleanup: cancel any active subscription so the
  # operator stops getting charged after the local row is gone.
  # Don't delete the Stripe customer — Stripe wants those preserved
  # for invoice history. The customer becomes orphaned but harmless.
  class Destroy < ApplicationCommand
    option :account
    option :acted_by_user, optional: true, default: -> { nil }

    def call
      return failure([ "missing_account" ]) if account.blank?

      ActiveRecord::Base.transaction do
        cancel_stripe_subscription_if_any
        sign_out_all_sessions
        account.destroy!
      end

      success(true)
    rescue ActiveRecord::RecordNotDestroyed, Stripe::StripeError => e
      Rails.logger.error("Accounts::Destroy: #{e.class}: #{e.message}")
      failure([ e.message ])
    end

    private

    def cancel_stripe_subscription_if_any
      sub_id = account.subscription&.stripe_subscription_id
      return if sub_id.blank?

      Stripe::Subscription.cancel(sub_id, prorate: false, invoice_now: false)
    rescue Stripe::InvalidRequestError => e
      # Already canceled / unknown — nothing left to clean up.
      Rails.logger.warn("Accounts::Destroy stripe cancel skipped: #{e.message}")
    end

    # End every active session so a cookie left in another browser
    # doesn't keep showing a logged-in shell after the destroy. The
    # owner's User row gets pulled by `account.destroy!` via
    # `users` cascade.
    def sign_out_all_sessions
      account.users.find_each do |user|
        user.sessions.delete_all
      end
    end
  end
end
