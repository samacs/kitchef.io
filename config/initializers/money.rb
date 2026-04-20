require "money-rails"

# Kitchef is MXN-only. We deliberately do not install any FX helpers or
# multi-currency formatters — the moment we support another currency we
# need to revisit every storefront, invoice, and report.
MoneyRails.configure do |config|
  config.default_currency = :mxn

  # Display as "$1,250.00" — no "MX$" prefix, no "MXN" suffix. The peso sign
  # alone is unambiguous in product UI because we do not accept any other
  # currency.
  config.no_cents_if_whole = false
  config.locale_backend    = :i18n
  config.rounding_mode     = BigDecimal::ROUND_HALF_UP
end

# Money gem itself — keep the default symbol as $ and suppress the ISO suffix.
Money.default_currency = Money::Currency.new(:mxn)
Money.locale_backend   = :i18n
Money.rounding_mode    = BigDecimal::ROUND_HALF_UP
