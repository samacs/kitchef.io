module Subscriptions
  # Switch a paying Stripe subscription between Pro Mensual and Pro
  # Anual. Uses Stripe's `proration_behavior: 'create_prorations'`
  # so the operator gets credit for the unused portion of the
  # current cycle and is charged the prorated difference on the new
  # cycle. UI surfaces the prorated amount via Stripe's
  # `upcoming_invoice` preview before she confirms (Slice 5
  # dashboard).
  #
  # Mensual → Anual = always allowed (proration usually positive).
  # Anual → Mensual = allowed but not encouraged. Stripe handles the
  # math identically.
  class ChangeBillingPeriod < ApplicationCommand
    BILLING_PERIODS = %w[monthly yearly].freeze

    option :subscription
    option :billing_period

    def call
      return failure([ "invalid_billing_period" ]) unless BILLING_PERIODS.include?(billing_period.to_s)
      return failure([ "no_stripe_subscription" ]) if subscription.stripe_subscription_id.blank?
      return failure([ "not_stripe_managed"     ]) unless subscription.source_stripe?
      return failure([ "already_on_that_plan"   ]) if already_on_target_plan?

      stripe_sub = Stripe::Subscription.retrieve(subscription.stripe_subscription_id)
      first_item = stripe_sub.items.data.first

      updated = Stripe::Subscription.update(
        subscription.stripe_subscription_id,
        items:               [ { id: first_item.id, price: target_price_id } ],
        proration_behavior:  "create_prorations",
        billing_cycle_anchor: "now"
      )

      Subscriptions::SyncFromStripe.call(stripe_subscription: updated)
      success(subscription.reload)
    rescue Stripe::StripeError => e
      Rails.logger.error("ChangeBillingPeriod: #{e.class}: #{e.message}")
      failure([ e.message ])
    end

    # Class method: previews what the prorated charge / credit will
    # be without applying the change. Used by the dashboard so the
    # operator sees the dollar number before she clicks "Cambiar".
    def self.preview(subscription:, billing_period:)
      return nil if subscription.stripe_subscription_id.blank?
      return nil unless BILLING_PERIODS.include?(billing_period.to_s)

      stripe_sub  = Stripe::Subscription.retrieve(subscription.stripe_subscription_id)
      first_item  = stripe_sub.items.data.first
      target      = price_id_for(billing_period)
      return nil if first_item.price.id == target

      invoice = Stripe::Invoice.upcoming(
        customer:           stripe_sub.customer,
        subscription:       stripe_sub.id,
        subscription_items: [ { id: first_item.id, price: target } ],
        subscription_proration_behavior: "create_prorations"
      )

      { amount_cents: invoice.amount_due, currency: invoice.currency }
    rescue Stripe::StripeError
      nil
    end

    def self.price_id_for(period)
      case period.to_s
      when "monthly" then Marketing::PricingCatalog::PRO_MONTHLY_STRIPE_PRICE_ID
      when "yearly"  then Marketing::PricingCatalog::PRO_YEARLY_STRIPE_PRICE_ID
      end
    end

    private

    def target_price_id
      self.class.price_id_for(billing_period)
    end

    def already_on_target_plan?
      target = "pro_#{billing_period}"
      subscription.plan.to_s == target
    end
  end
end
