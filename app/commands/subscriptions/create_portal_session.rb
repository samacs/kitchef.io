module Subscriptions
  # Opens a Stripe Billing Portal session so the operator can update
  # her card / address from Stripe's hosted UI. We only use Portal
  # for things Stripe owns better than us — payment methods, billing
  # address, tax IDs. Plan switching, cancellation, and invoice
  # listing all stay inside Kitchef so the brand and copy land.
  #
  # The portal config is taken from Stripe's default — we don't pin
  # a custom config until we want to lock down which actions the
  # portal exposes (right now its features are limited to "update
  # payment method" because we haven't enabled the rest in the
  # Stripe dashboard).
  class CreatePortalSession < ApplicationCommand
    option :account
    option :return_url

    def call
      return failure([ "stripe_not_enabled" ]) unless Subscriptions.stripe_enabled?
      return failure([ "demo_account_blocked" ]) if account.demo?

      customer_id = account.subscription&.stripe_customer_id
      return failure([ "no_stripe_customer" ]) if customer_id.blank?

      session = Stripe::BillingPortal::Session.create(
        customer:   customer_id,
        return_url: return_url,
        locale:     "es-419"
      )
      success(session)
    rescue Stripe::StripeError => e
      Rails.logger.error("CreatePortalSession: #{e.class}: #{e.message}")
      failure([ e.message ])
    end
  end
end
