module Marketing
  # Single source of truth for the pricing copy that appears on the
  # marketing site. Stripe is the source of truth for what gets
  # *charged*; this catalog formats the same numbers for the cards
  # so an operator's eyes match the receipt she'll see in
  # `/letter_opener` after Slice 3 wires Checkout.
  #
  # Keeping this as a constant-backed module (not an ActiveRecord
  # row) means a price change is a one-file PR + a Stripe price
  # update — no migration, no admin UI, no risk of catalog/Stripe
  # drift in production.
  module PricingCatalog
    module_function

    PRO_MONTHLY_AMOUNT_CENTS = 19_900   # $199.00 MXN
    PRO_YEARLY_AMOUNT_CENTS  = 199_000  # $1,990.00 MXN

    # Stripe sandbox price IDs (CLAUDE.md).
    PRO_MONTHLY_STRIPE_PRICE_ID = "price_1TQgsp58g89ERoPrzw3U7GQ5".freeze
    PRO_YEARLY_STRIPE_PRICE_ID  = "price_1TQgsp58g89ERoPrPaVTz8A3".freeze

    PRO_PRODUCT_ID = "prod_UPVu3WmAhMdJKm".freeze

    # Two months free vs paying monthly:
    # 12 * $199 = $2,388  vs  $1,990  →  $398 saved → 16.65%
    YEARLY_SAVINGS_PCT = 17

    # Per-period UI strings. Returned as plain hashes so the component
    # can render them via `data-monthly` / `data-yearly` and let the
    # Stimulus controller swap them on toggle.
    def pro
      {
        monthly: {
          amount:      "$199",
          period:      "/mes",
          billed_note: I18n.t("marketing.pricing_cards.pro.billed.monthly")
        },
        yearly: {
          amount:      "$1,990",
          period:      "/año",
          billed_note: I18n.t("marketing.pricing_cards.pro.billed.yearly")
        }
      }.freeze
    end

    def free
      {
        amount:      "$0",
        period:      "/mes",
        billed_note: I18n.t("marketing.pricing_cards.free.billed")
      }.freeze
    end

    def yearly_savings_pct
      YEARLY_SAVINGS_PCT
    end
  end
end
