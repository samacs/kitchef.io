module Webhooks
  # Stripe webhook receiver. Real implementation will verify the signature
  # via Stripe::Webhook.construct_event and dispatch to the right handler
  # (invoice.paid, customer.subscription.updated, …) through a Billing::*
  # command. Signature verification happens BEFORE parsing the payload —
  # don't trust anything in the body until the HMAC matches.
  class StripeController < BaseController
    def create
      head :accepted
    end
  end
end
