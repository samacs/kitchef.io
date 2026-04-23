module Schedules
  # Computes the list of delivery options the storefront picker presents
  # to the customer. Reads the account's `Schedule`, applies:
  #
  #   * `order_mode` — advance / same_day / both
  #   * `lead_time_minutes` — for advance windows, the earliest acceptable
  #     start time is (now + lead_time). Windows fully in the past after
  #     that are dropped.
  #   * Date-specific exceptions — if today has an override, it replaces
  #     the recurring weekly slot.
  #
  # Output is a list of `Day` structs, each containing a list of `Window`s
  # plus an optional `asap` flag. Empty list when the kitchen has no
  # schedule configured yet (storefront shows "Por encargo · WhatsApp").
  class AvailableWindows < ApplicationService
    Window = Data.define(:date, :from_time, :to_time, :kind) do
      # Stable identifier the form posts + the server re-validates on submit.
      # "asap|YYYY-MM-DD" for ASAP, "window|YYYY-MM-DD|HHMM-HHMM" for a slot.
      def id
        kind == :asap ? "asap|#{date}" : "window|#{date}|#{format_time(from_time)}-#{format_time(to_time)}"
      end

      def from_time_hhmm = format_time(from_time)
      def to_time_hhmm   = format_time(to_time)

      private

      def format_time(minutes)
        minutes && format("%02d:%02d", minutes / 60, minutes % 60)
      end
    end

    Day = Data.define(:date, :windows)

    # How far out to surface upcoming windows for advance / both modes.
    HORIZON_DAYS = 14

    option :account
    option :from, default: -> { Time.current.in_time_zone("America/Mexico_City") }

    def self.for(account:, from: Time.current.in_time_zone("America/Mexico_City"))
      call(account: account, from: from)
    end

    def call
      return empty_result if schedule.nil?

      days = collect_days
      return empty_result if days.all? { |d| d.windows.empty? }

      days
    end

    # Given a window id string + posted at time, re-derive the underlying
    # `Window`. Returns nil if the id no longer maps to anything live
    # (e.g. the operator deleted the window between render and submit).
    def self.decode(account:, id:, at: Time.current.in_time_zone("America/Mexico_City"))
      return nil if id.blank?

      kind, date_str, range = id.split("|", 3)
      return nil unless date_str.present?

      date = Date.parse(date_str)
      days = self.for(account: account, from: at)
      day  = days.find { |d| d.date == date }
      return nil if day.nil?

      case kind
      when "asap"
        day.windows.find { |w| w.kind == :asap }
      when "window"
        from_s, to_s = range.to_s.split("-", 2)
        from_min = parse_hhmm(from_s)
        to_min   = parse_hhmm(to_s)
        day.windows.find { |w| w.kind == :scheduled && w.from_time == from_min && w.to_time == to_min }
      end
    rescue Date::Error, ArgumentError
      nil
    end

    def self.parse_hhmm(str)
      h, m = str.to_s.split(":")
      (h.to_i * 60) + m.to_i
    end

    private

    def schedule
      account.schedule
    end

    def collect_days
      range = (from.to_date..(from.to_date + HORIZON_DAYS.days))
      range.map { |date| Day.new(date: date, windows: windows_for(date)) }
    end

    def windows_for(date)
      out = []
      # ASAP gets added only to today, and only when the kitchen is in a
      # mode that permits same-day dispatch AND the kitchen is actually
      # "open" right now (not past the last window or on a closed day).
      if date == from.to_date && same_day_allowed? && open_now?
        out << Window.new(date: date, from_time: nil, to_time: nil, kind: :asap)
      end

      if scheduled_allowed?
        schedule.windows_for(date).each do |availability|
          next if date == from.to_date && availability.to_time <= earliest_minutes
          out << Window.new(
            date:      date,
            from_time: availability.from_time,
            to_time:   availability.to_time,
            kind:      :scheduled
          )
        end
      end

      out
    end

    def empty_result
      []
    end

    def same_day_allowed?
      schedule.order_mode_same_day? || schedule.order_mode_both?
    end

    def scheduled_allowed?
      schedule.order_mode_advance? || schedule.order_mode_both?
    end

    # Earliest acceptable start minute today, accounting for lead time.
    # Same-day kitchens bypass lead time (that's what "ASAP" is for);
    # for advance/both we honor the operator's configured lead_time.
    def earliest_minutes
      base = (from.hour * 60) + from.min
      return base if schedule.order_mode_same_day?

      base + schedule.lead_time_minutes.to_i
    end

    def open_now?
      schedule.open_at?(from)
    end
  end
end
