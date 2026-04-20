module Storefronts
  # Parses `account.public_profile.ordering_hours` (a JSON string) into a
  # usable weekly schedule and answers the two questions the storefront
  # cares about at render time:
  #
  #   - Is the kitchen accepting orders right now?
  #   - If closed, when does it next open?
  #
  # The schedule is a map of day-of-week (0..6, Sunday=0 per Ruby's `wday`)
  # to either `"closed"` or `{ "open" => "HH:MM", "close" => "HH:MM" }`.
  # Times live in the account's `time_zone` so a "Saturday 9am" slot means
  # 9am local regardless of UTC drift.
  #
  # Submissions are NOT blocked when closed — the customer might be
  # ordering for tomorrow. This service is only for the hero chip that
  # sets expectations.
  class OrderingHours
    Result = Struct.new(:open_now, :today_window, :next_opening_day, :next_opening_time, keyword_init: true) do
      def open_now? = open_now
    end

    DAY_KEYS = %w[Dom Lun Mar Mié Jue Vie Sáb].freeze  # Ruby wday 0..6
    DAY_FULL = %w[domingo lunes martes miércoles jueves viernes sábado].freeze

    def self.for(account)
      new(account).call
    end

    def initialize(account)
      @account  = account
      @schedule = parse(account.public_profile.ordering_hours)
      @now      = Time.current.in_time_zone(account.time_zone)
    end

    def call
      today_entry = @schedule[@now.wday]
      open_today, window = open_at?(today_entry, @now.strftime("%H:%M"))

      if open_today
        Result.new(
          open_now:          true,
          today_window:      window,
          next_opening_day:  nil,
          next_opening_time: nil
        )
      else
        day, time = next_opening(from_wday: @now.wday, from_time: @now.strftime("%H:%M"))
        Result.new(
          open_now:          false,
          today_window:      nil,
          next_opening_day:  day,
          next_opening_time: time
        )
      end
    end

    # Class-level helper for the view layer — returns the Spanish chip
    # label for a given Result, e.g. "Aceptando pedidos · Vie 9:00–18:00"
    # or "Abrimos el jueves 9:00". Kept here (not in the view) so the
    # logic is unit-testable and consistent between the hero and info strip.
    def self.chip_label(result)
      return nil if result.blank?

      if result.open_now?
        "Aceptando pedidos · #{DAY_KEYS[Time.current.wday]} #{result.today_window}"
      elsif result.next_opening_day
        "Abrimos el #{DAY_FULL[result.next_opening_day]} #{result.next_opening_time}"
      else
        "Por encargo · WhatsApp"
      end
    end

    private

    def parse(raw)
      return {} if raw.blank?

      decoded = JSON.parse(raw)
      decoded.each_with_object({}) do |(k, v), acc|
        acc[k.to_i] = v
      end
    rescue JSON::ParserError
      {}
    end

    def open_at?(entry, current_time_str)
      return [ false, nil ] if entry.blank? || entry == "closed"

      open_t  = entry["open"]
      close_t = entry["close"]
      return [ false, nil ] if open_t.blank? || close_t.blank?

      if current_time_str >= open_t && current_time_str < close_t
        [ true, "#{open_t}–#{close_t}" ]
      else
        [ false, nil ]
      end
    end

    def next_opening(from_wday:, from_time:)
      # Today first: if there's a window later today we haven't hit yet.
      today = @schedule[from_wday]
      if today.is_a?(Hash) && today["open"].present? && today["open"] > from_time
        return [ from_wday, today["open"] ]
      end

      7.times do |offset|
        day = (from_wday + offset + 1) % 7
        entry = @schedule[day]
        next if entry.blank? || entry == "closed"
        open_t = entry["open"]
        next if open_t.blank?
        return [ day, open_t ]
      end

      [ nil, nil ]
    end
  end
end
