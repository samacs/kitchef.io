module Accounts
  # Weekly ordering-hours grid. Lets the operator toggle "Cerrado" per day
  # and pick open/close times without dropping into a rails console.
  # Serializes its state into a single hidden field named
  # `account[public_profile][ordering_hours]` that the form posts alongside
  # the rest of the profile — the existing autosave pipeline writes it via
  # `Accounts::Update`, no special handling required.
  #
  # The JSON shape matches `Storefronts::OrderingHours#parse`:
  #   { "0":"closed", "1":{"open":"09:00","close":"18:00"}, ... }
  # Keys are Ruby `wday` (Sunday=0..Saturday=6).
  class OrderingHoursEditorComponent < ApplicationComponent
    # Display order: start the week on Monday. Spanish-first labels — the
    # one place we NOT use the wday order directly.
    DAY_LABELS = [
      [ 1, "Lunes" ],
      [ 2, "Martes" ],
      [ 3, "Miércoles" ],
      [ 4, "Jueves" ],
      [ 5, "Viernes" ],
      [ 6, "Sábado" ],
      [ 0, "Domingo" ]
    ].freeze

    option :account

    # Parses the current schedule JSON into a hash keyed by wday integer.
    # Falls back to a sensible default (Lun–Sáb 09:00–18:00, Sun closed)
    # when the field is empty so the first render isn't all "Cerrado".
    def schedule
      @schedule ||= begin
        raw = account.public_profile.ordering_hours
        parsed = raw.present? ? JSON.parse(raw) : nil
        normalize(parsed || default_schedule)
      rescue JSON::ParserError
        normalize(default_schedule)
      end
    end

    def entry_for(wday)
      schedule[wday] || { "open" => "", "close" => "", "closed" => false }
    end

    private

    def normalize(hash)
      hash.each_with_object({}) do |(k, v), acc|
        key = k.to_i
        acc[key] =
          if v == "closed"
            { "open" => "09:00", "close" => "18:00", "closed" => true }
          elsif v.is_a?(Hash)
            { "open" => v["open"].to_s, "close" => v["close"].to_s, "closed" => false }
          else
            { "open" => "09:00", "close" => "18:00", "closed" => true }
          end
      end
    end

    def default_schedule
      (1..6).each_with_object("0" => "closed") do |wday, acc|
        acc[wday.to_s] = { "open" => "09:00", "close" => "18:00" }
      end
    end
  end
end
