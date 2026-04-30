module Subscriptions
  # Immediately drop the operator from Pro back to Free. Cancels the
  # Stripe subscription with `prorate: false` so we don't issue a
  # mid-cycle credit (matches the cancel-flow promise: "tienes acceso
  # completo hasta el último día de tu ciclo"). The Stripe webhook
  # then flips `source` to `:free` locally; we also pre-flip it here
  # for snappy UX so the operator sees the dashboard update before
  # the webhook lands.
  #
  # If the operator is on a `:comp` source we just clear the comp
  # fields — there's no Stripe state to cancel.
  class DowngradeToFree < ApplicationCommand
    option :subscription
    option :reason, optional: true, default: -> { nil }

    def call
      case subscription.source
      when "stripe"  then downgrade_stripe!
      when "comp"    then downgrade_comp!
      when "sandbox" then downgrade_sandbox!
      else
        success(subscription)
      end
    rescue Stripe::StripeError => e
      Rails.logger.error("DowngradeToFree: #{e.class}: #{e.message}")
      failure([ e.message ])
    end

    private

    def downgrade_sandbox!
      subscription.update!(
        source: :free,
        plan:   :free,
        status: :active
      )
      success(subscription)
    end

    def downgrade_stripe!
      sub_id = subscription.stripe_subscription_id
      if sub_id.present? && Subscriptions.stripe_enabled?
        Stripe::Subscription.cancel(sub_id, prorate: false, invoice_now: false)
      end

      subscription.update!(
        source:                 :free,
        plan:                   :free,
        status:                 :ended,
        stripe_subscription_id: nil,
        current_period_end:     nil,
        trial_ends_at:          nil,
        cancel_at_period_end:   false
      )
      success(subscription)
    end

    def downgrade_comp!
      subscription.update!(
        source:             :free,
        plan:               :free,
        status:             :ended,
        comp_granted_by_id: nil,
        comp_reason:        nil,
        comp_expires_at:    nil
      )
      success(subscription)
    end
  end
end
