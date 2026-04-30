module Subscriptions
  # Attach the standing save-flow coupon (50% off × 3 months) to the
  # operator's Stripe subscription. Used by the cancel save-flow when
  # the operator picks "Muy caro" as the exit reason. Non-stackable
  # by Stripe default, so calling this twice on the same subscription
  # has no effect on the second call (Stripe replaces the previous
  # discount).
  class ApplySaveCoupon < ApplicationCommand
    # Created in Stripe sandbox during Phase 14 setup; documented in
    # CLAUDE.md (Billing section). If the coupon ever rotates,
    # update CLAUDE.md alongside this constant.
    SAVE_COUPON_ID = "ucUpunx9".freeze

    option :subscription

    def call
      return failure([ "stripe_not_enabled" ]) unless Subscriptions.stripe_enabled?
      return failure([ "no_stripe_subscription" ]) if subscription.stripe_subscription_id.blank?
      return failure([ "not_stripe_managed"     ]) unless subscription.source_stripe?

      Stripe::Subscription.update(
        subscription.stripe_subscription_id,
        discounts: [ { coupon: SAVE_COUPON_ID } ]
      )

      success(subscription)
    rescue Stripe::StripeError => e
      Rails.logger.error("ApplySaveCoupon: #{e.class}: #{e.message}")
      failure([ e.message ])
    end
  end
end
