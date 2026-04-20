module Orders
  # Normalizes a user-submitted price into integer cents for persistence.
  # Operators type pesos ("12", "12.5", "1,250.00", "$450"), but every
  # monetary column is BIGINT cents. The form ships the peso string as
  # `unit_price`; this service is the single conversion point.
  #
  # Rules:
  #   - Blank submission → fallback cents (almost always the recipe's
  #     current sale_price_cents).
  #   - Strips "$", thousands separators (","), and whitespace.
  #   - Parses via BigDecimal so fractional pesos round half-up to whole
  #     cents (banker's rounding would surprise tax-calculation later).
  #   - Negative → 0 (free item). Non-numeric → fallback.
  #   - Accepts the legacy integer-cents form field for hand-crafted
  #     requests (backend stability).
  class PriceInCents < ApplicationService
    option :submitted, optional: true
    option :fallback_cents, default: -> { 0 }

    def call
      return fallback_cents.to_i if submitted.blank?

      normalized = normalize(submitted)
      return fallback_cents.to_i if normalized.blank?

      pesos = BigDecimal(normalized)
      cents = (pesos * 100).round
      cents.negative? ? 0 : cents.to_i
    rescue ArgumentError
      fallback_cents.to_i
    end

    private

    def normalize(value)
      value.to_s.delete("$").delete(",").strip
    end
  end
end
