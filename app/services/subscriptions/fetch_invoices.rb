module Subscriptions
  # Pulls a customer's invoice history from Stripe and returns a
  # plain Ruby array of structs the view can render. We don't cache
  # locally — Stripe is the source of truth for invoice state
  # (paid / open / uncollectible) and the SDK call is fast enough
  # for the dozen-rows-per-operator scale we're at.
  #
  # Returns [] when the account has no Stripe customer (Free /
  # comp / demo accounts), which lets the caller render a calm
  # empty state rather than branching on a missing customer id.
  class FetchInvoices < ApplicationService
    Row = Struct.new(:id, :number, :status, :amount_cents, :currency,
                     :created_at, :period_start, :period_end,
                     :invoice_pdf, :hosted_invoice_url,
                     keyword_init: true)

    option :account
    option :limit, default: -> { 24 }

    def call
      return [] unless Subscriptions.stripe_enabled?

      customer_id = account.subscription&.stripe_customer_id
      return [] if customer_id.blank?

      Stripe::Invoice.list(customer: customer_id, limit: limit, expand: %w[data.subscription])
                     .data
                     .map { |inv| build_row(inv) }
    rescue Stripe::StripeError => e
      Rails.logger.warn("FetchInvoices: #{e.class}: #{e.message}")
      []
    end

    private

    def build_row(invoice)
      Row.new(
        id:                 invoice.id,
        number:             invoice.number,
        status:             invoice.status,
        amount_cents:       invoice.amount_paid.to_i.positive? ? invoice.amount_paid : invoice.amount_due,
        currency:           invoice.currency&.upcase || "MXN",
        created_at:         invoice.created.present? ? Time.zone.at(invoice.created) : nil,
        period_start:       invoice.period_start.present? ? Time.zone.at(invoice.period_start) : nil,
        period_end:         invoice.period_end.present? ? Time.zone.at(invoice.period_end) : nil,
        invoice_pdf:        invoice.invoice_pdf,
        hosted_invoice_url: invoice.hosted_invoice_url
      )
    end
  end
end
