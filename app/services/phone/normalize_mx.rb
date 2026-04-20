module Phone
  # Turns a Mexican phone as an operator actually types it into canonical
  # E.164 `+52XXXXXXXXXX`. Handles every form we see in the wild:
  #
  #   "662 188 4355"         10 digits + spaces
  #   "662-188-4355"         10 digits + dashes
  #   "(662) 188-4355"       parens + dashes
  #   "52 662 188 4355"      country code no +
  #   "+52 662 188 4355"     country code + spaces
  #   "+521 662 188 4355"    WhatsApp-style extra "1" for mobile
  #   "+5216621884355"       WhatsApp-style, compact
  #   "6621884355"           bare
  #
  # Strategy: strip everything except digits, peel off the `52` / `521`
  # country + WhatsApp prefix if present, expect 10 digits left, and
  # re-stamp `+52`. Returns nil for anything we can't fit into that
  # shape so the validator can surface an error.
  #
  # Phonelib strict-check also rejects loosely-formatted input, so we
  # feed it the normalized E.164 form downstream — which it accepts.
  class NormalizeMx < ApplicationService
    option :raw

    def call
      digits = raw.to_s.gsub(/\D/, "")
      return nil if digits.empty?

      local = strip_prefix(digits)
      return nil unless local&.length == 10

      "+52#{local}"
    end

    private

    def strip_prefix(digits)
      # 13 digits starting with 521: WhatsApp-style mobile → drop "521".
      return digits[3..] if digits.length == 13 && digits.start_with?("521")
      # 12 digits starting with 52: standard MX country code → drop "52".
      return digits[2..] if digits.length == 12 && digits.start_with?("52")
      # 11 digits starting with 1: leading-1 variant (occasional WhatsApp
      # copy-paste from a `+52 1 ...` chat) → drop the "1".
      return digits[1..] if digits.length == 11 && digits.start_with?("1")
      # Plain 10-digit local mobile — keep as-is.
      return digits      if digits.length == 10
      nil
    end
  end
end
