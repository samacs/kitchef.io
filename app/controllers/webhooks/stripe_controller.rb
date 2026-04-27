module Webhooks
  # Stripe webhook receiver for Phase 14 subscription events. Verifies
  # the request signature with `STRIPE_WEBHOOK_SECRET_KEY` BEFORE
  # parsing the body — anything that fails verification gets a 400 and
  # never reaches our domain code.
  #
  # On success we ALWAYS reply 200 (`head :ok`) even if the event
  # doesn't match a local Account. Returning a non-2xx tells Stripe to
  # retry, and a missing-account event isn't worth retrying — the
  # local row simply doesn't exist (or got deleted), and we don't want
  # the queue to fill up with replays we can't resolve.
  class StripeController < BaseController
    HANDLED_EVENTS = %w[
      checkout.session.completed
      customer.subscription.created
      customer.subscription.updated
      customer.subscription.deleted
      customer.subscription.paused
      customer.subscription.resumed
      invoice.paid
      invoice.payment_failed
    ].freeze

    def create
      event = construct_event
      return head(:bad_request) if event.nil?

      handle(event)
      head :ok
    rescue StandardError => e
      Rails.logger.error("StripeWebhook: #{e.class}: #{e.message}")
      Rails.logger.error(e.backtrace&.first(8)&.join("\n"))
      head :ok
    end

    private

    def construct_event
      payload   = request.body.read
      signature = request.env["HTTP_STRIPE_SIGNATURE"]
      secret    = ENV["STRIPE_WEBHOOK_SECRET_KEY"].to_s

      return nil if signature.blank? || secret.blank?

      Stripe::Webhook.construct_event(payload, signature, secret)
    rescue JSON::ParserError, Stripe::SignatureVerificationError => e
      Rails.logger.warn("StripeWebhook signature/parse failed: #{e.message}")
      nil
    end

    def handle(event)
      return unless HANDLED_EVENTS.include?(event.type)

      case event.type
      when "checkout.session.completed"   then on_checkout_completed(event)
      when /\Acustomer\.subscription\.(created|updated|paused|resumed)\z/
        sync_subscription(event.data.object.id)
      when "customer.subscription.deleted" then on_subscription_deleted(event)
      when "invoice.paid"                  then on_invoice_paid(event)
      when "invoice.payment_failed"        then on_invoice_payment_failed(event)
      end
    end

    # Pull the live subscription state and write it locally. Trust the
    # canonical sync service rather than the embedded payload — Stripe
    # objects on a webhook can lag a saved-elsewhere update by a tick.
    def sync_subscription(stripe_subscription_id)
      Subscriptions::SyncFromStripe.call(stripe_subscription_id: stripe_subscription_id)
    end

    def on_checkout_completed(event)
      sub_id = event.data.object.subscription
      return if sub_id.blank?

      Subscriptions::SyncFromStripe.call(stripe_subscription_id: sub_id)
      mark_customer_trialed(event.data.object.customer)
    end

    def on_subscription_deleted(event)
      stripe_sub = event.data.object
      local = Subscription.find_by(stripe_subscription_id: stripe_sub.id)
      return if local.nil?

      local.update!(
        source:                 :free,
        plan:                   :free,
        status:                 :canceled,
        stripe_subscription_id: nil,
        current_period_end:     nil,
        trial_ends_at:          nil,
        cancel_at_period_end:   false
      )
    end

    def on_invoice_paid(event)
      sub_id = event.data.object.subscription
      sync_subscription(sub_id) if sub_id.present?
    end

    def on_invoice_payment_failed(event)
      sub_id = event.data.object.subscription
      return if sub_id.blank?
      local  = Subscription.find_by(stripe_subscription_id: sub_id)
      local&.update!(status: :past_due)
    end

    # Stamp `has_trialed` on the Stripe customer so a future Checkout
    # session knows not to grant a second trial. We do this even on
    # mid-trial conversions (someone signs up, finishes Checkout, never
    # actually waits 14 days) — once they've claimed the trial, that's it.
    def mark_customer_trialed(customer_id)
      return if customer_id.blank?
      Stripe::Customer.update(customer_id, metadata: { has_trialed: "true" })
    rescue Stripe::StripeError => e
      Rails.logger.warn("Failed to mark customer trialed (#{customer_id}): #{e.message}")
    end
  end
end
