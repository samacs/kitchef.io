module Storefronts
  # Answers the two questions the storefront hero + info strip care about
  # at render time, using the account's `Schedule`:
  #
  #   - Is the kitchen accepting orders right now?
  #   - If closed, when does it next open?
  #
  # Recurring weekly availabilities on the schedule drive the answer. A
  # date-specific exception (e.g. "Dec 25 closed" or "Dec 24 closes early")
  # supersedes the recurring window on that specific day. Order submissions
  # are NEVER blocked by this service — the hero chip only sets the
  # customer's expectation for when the kitchen is active.
  class OrderingHours
    Result = Struct.new(:open_now, :today_window, :next_opening_day, :next_opening_time, keyword_init: true) do
      def open_now? = open_now
    end

    DAY_KEYS = %w[Dom Lun Mar Mié Jue Vie Sáb].freeze
    DAY_FULL = %w[domingo lunes martes miércoles jueves viernes sábado].freeze

    def self.for(account)
      new(account).call
    end

    def initialize(account)
      @account  = account
      @schedule = account.schedule
      @now      = Time.current.in_time_zone(account.time_zone)
    end

    def call
      return empty_result if @schedule.nil?

      today_windows = @schedule.windows_for(@now.to_date)
      now_minutes   = (@now.hour * 60) + @now.min

      active_window = today_windows.find { |w| now_minutes >= w.from_time && now_minutes < w.to_time }

      if active_window
        Result.new(
          open_now:          true,
          today_window:      "#{active_window.from_time_hhmm}–#{active_window.to_time_hhmm}",
          next_opening_day:  nil,
          next_opening_time: nil
        )
      else
        day, time = next_opening(from_minutes: now_minutes, today_windows: today_windows)
        Result.new(
          open_now:          false,
          today_window:      nil,
          next_opening_day:  day,
          next_opening_time: time
        )
      end
    end

    # Chip label used by the storefront hero + info strip. Copy doesn't
    # depend on the data shape — kept here so renderers stay dumb.
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

    def empty_result
      Result.new(open_now: false, today_window: nil, next_opening_day: nil, next_opening_time: nil)
    end

    # Walks forward from today: first any later window today, then the
    # next seven days. Looks at recurring availabilities + exceptions for
    # each date via `Schedule#windows_for`.
    def next_opening(from_minutes:, today_windows:)
      upcoming_today = today_windows.find { |w| w.from_time > from_minutes }
      return [ @now.wday, format_time(upcoming_today.from_time) ] if upcoming_today

      (1..7).each do |offset|
        date = @now.to_date + offset.days
        window = @schedule.windows_for(date).min_by(&:from_time)
        return [ date.wday, format_time(window.from_time) ] if window
      end

      [ nil, nil ]
    end

    def format_time(minutes)
      format("%02d:%02d", minutes / 60, minutes % 60)
    end
  end
end
