module Runner
  # Signed, opaque token used by `/r/:token`. Encodes the account + target
  # date using Rails' own `message_verifier`, so the signature rotates
  # with `secret_key_base` and we don't pull in a JWT dependency for what
  # is effectively a tamper-evident blob.
  #
  # Expiration is implicit in the encoded date — decoding a token whose
  # date is more than 24h in the past raises `Invalid`. No separate
  # `expires_at` field; the date IS the expiration window. An operator
  # bookmarking the URL for "today" at 7am still works all evening, and
  # stops working the next morning.
  class Token
    Invalid = Class.new(StandardError)

    PURPOSE = :runner_day

    def self.encode(account:, date:)
      verifier.generate(
        {
          account_id:   account.id,
          date:         date.to_s,
          generated_at: Time.current.to_i
        },
        purpose: PURPOSE
      )
    end

    def self.decode(token)
      payload = verifier.verify(token.to_s, purpose: PURPOSE)
      date = Date.parse(payload.fetch("date"))
      raise Invalid, "expired" if date < (Date.current - 1)

      Decoded.new(
        account_id:   payload.fetch("account_id"),
        date:         date,
        generated_at: Time.at(payload.fetch("generated_at"))
      )
    rescue ActiveSupport::MessageVerifier::InvalidSignature,
           ActiveSupport::MessageEncryptor::InvalidMessage,
           ArgumentError,
           KeyError,
           TypeError,
           Date::Error => e
      raise Invalid, e.message
    end

    def self.verifier
      Rails.application.message_verifier(:runner)
    end

    Decoded = Data.define(:account_id, :date, :generated_at)
  end
end
