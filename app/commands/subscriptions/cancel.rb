module Subscriptions
  # Soft-cancel a Stripe subscription: sets `cancel_at_period_end =
  # true` on Stripe so the operator keeps full Pro access until her
  # period closes. After period_end, Stripe sends a
  # `customer.subscription.deleted` webhook which our handler
  # converts into `source: :free` locally.
  #
  # No mid-cycle refund (industry standard, called out in the
  # ROADMAP). The save-flow's coupon path is a separate command.
  class Cancel < ApplicationCommand
    option :subscription
    option :reason,    optional: true, default: -> { nil }

    def call
      return failure([ "stripe_not_enabled" ]) unless Subscriptions.stripe_enabled?
      return failure([ "no_stripe_subscription" ]) if subscription.stripe_subscription_id.blank?
      return failure([ "not_stripe_managed"   ]) unless subscription.source_stripe?

      stripe_sub = Stripe::Subscription.update(
        subscription.stripe_subscription_id,
        cancel_at_period_end: true,
        cancellation_details:  reason.present? ? { feedback: cancellation_feedback_for(reason) } : nil,
        metadata:              { cancel_reason: reason.to_s }
      )

      Subscriptions::SyncFromStripe.call(stripe_subscription: stripe_sub)
      success(subscription.reload)
    rescue Stripe::StripeError => e
      Rails.logger.error("Subscriptions::Cancel: #{e.class}: #{e.message}")
      failure([ e.message ])
    end

    private

    # Map our exit-survey reason values to Stripe's `cancellation_details.feedback` enum.
    # Stripe accepts: customer_service, low_quality, missing_features,
    # other, switched_service, too_complex, too_expensive,
    # unused.
    def cancellation_feedback_for(raw)
      case raw.to_s
      when "too_expensive"  then "too_expensive"
      when "not_using"      then "unused"
      when "missing_feature" then "missing_features"
      when "closing_kitchen" then "other"
      else "other"
      end
    end
  end
end
