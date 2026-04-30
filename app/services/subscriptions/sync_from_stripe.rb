module Subscriptions
  # Canonical "pull state from Stripe and write it locally" service.
  # Every webhook handler ends up calling this rather than mutating
  # `Subscription` directly — that way two webhooks arriving in the
  # wrong order can't leave us with a stale plan or status. The Stripe
  # `Subscription` object is the source of truth; our row is a cache.
  #
  # Resolves the local Subscription via `stripe_subscription_id` first
  # (most webhooks carry it). Falls back to `stripe_customer_id` for
  # customer-only events. If we still can't find an Account, that's a
  # real error the webhook handler should log + reply 200 anyway (so
  # Stripe stops retrying) — never re-raise here.
  #
  # Returns the updated Subscription, or nil if no matching account
  # exists in this database.
  class SyncFromStripe < ApplicationService
    option :stripe_subscription_id, optional: true, default: -> { nil }
    option :stripe_subscription,    optional: true, default: -> { nil }

    PRO_PRICE_IDS = {
      Marketing::PricingCatalog::PRO_MONTHLY_STRIPE_PRICE_ID => "pro_monthly",
      Marketing::PricingCatalog::PRO_YEARLY_STRIPE_PRICE_ID  => "pro_yearly"
    }.freeze

    def call
      return nil unless Subscriptions.stripe_enabled?

      stripe_sub = resolve_stripe_subscription
      return nil if stripe_sub.nil?

      local = local_subscription_for(stripe_sub)
      return nil if local.nil?

      apply!(local, stripe_sub)
      local
    end

    private

    def resolve_stripe_subscription
      return stripe_subscription if stripe_subscription
      return nil if stripe_subscription_id.blank?
      Stripe::Subscription.retrieve(stripe_subscription_id)
    rescue Stripe::InvalidRequestError => e
      Rails.logger.warn("SyncFromStripe: stripe sub not found #{stripe_subscription_id}: #{e.message}")
      nil
    end

    def local_subscription_for(stripe_sub)
      Subscription.find_by(stripe_subscription_id: stripe_sub.id) ||
        Subscription.find_by(stripe_customer_id: stripe_sub.customer)
    end

    def apply!(local, stripe_sub)
      plan_key = plan_for(stripe_sub)
      status   = status_for(stripe_sub)

      local.update!(
        source:                 :stripe,
        plan:                   plan_key || :free,
        status:                 status,
        stripe_customer_id:     stripe_sub.customer,
        stripe_subscription_id: stripe_sub.id,
        current_period_end:     period_end_for(stripe_sub),
        trial_ends_at:          trial_end_for(stripe_sub),
        cancel_at_period_end:   stripe_sub.cancel_at_period_end == true,
        # Comp fields are mutually exclusive with Stripe ownership.
        comp_granted_by_id:     nil,
        comp_reason:            nil,
        comp_expires_at:        nil
      )
    end

    def plan_for(stripe_sub)
      first_item = stripe_sub.items&.data&.first
      price_id   = first_item&.price&.id
      PRO_PRICE_IDS[price_id] || "pro"
    end

    # Map Stripe's status enum to our local one. Stripe values we care
    # about: "trialing", "active", "past_due", "canceled", "unpaid",
    # "incomplete", "incomplete_expired", "paused".
    def status_for(stripe_sub)
      case stripe_sub.status
      when "trialing"            then :trialing
      when "active"              then :active
      when "past_due", "unpaid"  then :past_due
      when "canceled"            then :canceled
      when "incomplete"          then :incomplete
      when "incomplete_expired"  then :ended
      when "paused"              then :paused
      else                            :ended
      end
    end

    def period_end_for(stripe_sub)
      raw = stripe_sub.current_period_end
      raw.present? ? Time.zone.at(raw) : nil
    end

    def trial_end_for(stripe_sub)
      raw = stripe_sub.trial_end
      raw.present? ? Time.zone.at(raw) : nil
    end
  end
end
