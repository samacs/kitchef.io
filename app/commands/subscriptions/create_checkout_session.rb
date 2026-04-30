module Subscriptions
  # Builds a Stripe Checkout Session for an operator upgrading to Pro.
  #
  # Trial defaults to 14 days, no card required (`payment_method_collection:
  # 'if_required'` keeps the operator promise in `marketing.pricing.no_card`).
  # If the account has already used a trial we skip the trial param so the
  # second go-around hits Checkout's standard payment-method capture
  # (Stripe enforces one-trial-per-customer via the customer-level
  # `metadata: { has_trialed: 'true' }` flag we write back when the
  # trial begins).
  #
  # Demo accounts are blocked at the controller layer; this command also
  # guards as belt-and-suspenders so a stray script can't accidentally
  # bill the demo customer.
  class CreateCheckoutSession < ApplicationCommand
    BILLING_PERIODS = %w[monthly yearly].freeze
    TRIAL_DAYS      = 14

    option :account
    option :user
    option :billing_period, default: -> { "monthly" }
    option :success_url
    option :cancel_url

    def call
      return failure([ "stripe_not_enabled" ]) unless Subscriptions.stripe_enabled?
      return failure([ "demo_account_blocked" ]) if account.demo?
      return failure([ "invalid_billing_period" ]) unless BILLING_PERIODS.include?(billing_period)

      customer    = stripe_customer_for(account, user)
      eligible    = trial_eligible?(customer)
      session     = create_session!(customer: customer, eligible_for_trial: eligible)
      remember_intent!(account: account, customer: customer, billing_period: billing_period)

      success(session)
    rescue Stripe::StripeError => e
      Rails.logger.error("CreateCheckoutSession failed: #{e.class}: #{e.message}")
      failure([ e.message ])
    end

    private

    # Return the account's existing Stripe customer or create one. We
    # write `account_id` into customer metadata so the webhook handler
    # can recover the local Account from a customer-only event (e.g.,
    # `customer.subscription.deleted`).
    def stripe_customer_for(account, user)
      sub = account.subscription || account.create_subscription!
      if sub.stripe_customer_id.present?
        Stripe::Customer.retrieve(sub.stripe_customer_id)
      else
        Stripe::Customer.create(
          email:    user.email_address,
          name:     [ user.first_name, user.last_name ].compact_blank.join(" "),
          metadata: { account_id: account.id, account_slug: account.slug }
        ).tap do |c|
          sub.update!(stripe_customer_id: c.id)
        end
      end
    end

    # First Pro signup ever for this account => eligible for trial.
    # Stripe's `customer.metadata.has_trialed` is the source of truth so
    # the second-trial guard is enforced even if our local flags get
    # out of sync.
    def trial_eligible?(customer)
      customer.metadata&.[]("has_trialed").to_s != "true"
    end

    def create_session!(customer:, eligible_for_trial:)
      Stripe::Checkout::Session.create(checkout_params(
        customer: customer,
        eligible_for_trial: eligible_for_trial
      ))
    end

    def checkout_params(customer:, eligible_for_trial:)
      base = {
        mode:          "subscription",
        customer:      customer.id,
        success_url:   success_url,
        cancel_url:    cancel_url,
        line_items:    [ { price: price_id, quantity: 1 } ],
        allow_promotion_codes: true,
        locale:        "es-419",
        subscription_data: {
          metadata: {
            account_id:      account.id,
            account_slug:    account.slug,
            billing_period:  billing_period
          }
        }
      }

      if eligible_for_trial
        base[:subscription_data][:trial_period_days] = TRIAL_DAYS
        # Trial without card capture — Stripe surfaces a "no card needed"
        # confirmation step. Once the trial ends, Stripe converts the
        # subscription to active automatically (with the saved payment
        # method, if any). We collect a card later via the Customer
        # Portal in Slice 5.
        base[:payment_method_collection] = "if_required"
      end

      base
    end

    def price_id
      case billing_period
      when "monthly" then Marketing::PricingCatalog::PRO_MONTHLY_STRIPE_PRICE_ID
      when "yearly"  then Marketing::PricingCatalog::PRO_YEARLY_STRIPE_PRICE_ID
      end
    end

    # Persist the cancel/return state we'll need on webhook arrival —
    # specifically, mirror the customer id locally so a webhook fired
    # before `checkout.session.completed` still finds an Account.
    def remember_intent!(account:, customer:, billing_period:)
      sub = account.subscription
      return if sub.nil?
      return if sub.stripe_customer_id.present?

      sub.update!(stripe_customer_id: customer.id)
    end
  end
end
