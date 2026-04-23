module Storefronts
  # Customer-facing delivery-window picker.
  #
  # Three branches share one component, driven by the kitchen's
  # `schedule.order_mode`:
  #
  #   * `same_day`  → single "Lo antes posible" pick-card.
  #   * `advance`   → date-chip strip (horizontal-scroll) + time-chip grid
  #                   for the selected date.
  #   * `both`      → segmented "Para hoy / Para después" at the top
  #                   flipping between the two branches above.
  #
  # The form posts a single `order[delivery_window_id]` string; the
  # `delivery-window-picker` Stimulus controller writes it every time the
  # selection changes. Server re-decodes via `Schedules::AvailableWindows.decode`
  # on submit — tampering with the hidden field can't defeat the schedule.
  class DeliveryWindowPickerComponent < ApplicationComponent
    DAY_SHORT = %w[Dom Lun Mar Mié Jue Vie Sáb].freeze

    option :account
    option :precomputed_days, default: -> { nil }
    option :selected_id,      default: -> { nil }

    # Callers may pre-compute windows (checkout controller does so to
    # disable submit when the schedule is empty). Falls back to a fresh
    # service call otherwise.
    def days
      @_days ||= precomputed_days || Schedules::AvailableWindows.for(account: account)
    end

    def any_windows?
      days.any? { |day| day.windows.any? }
    end

    def mode
      account.schedule&.order_mode || "advance"
    end

    # --- ASAP branch -------------------------------------------------
    #
    # There's at most one ASAP window — it lives on today's Day row
    # when the kitchen's schedule is currently open in same_day/both mode.
    def asap_window
      today = days.find { |d| d.date == Date.current }
      today&.windows&.find { |w| w.kind == :asap }
    end

    def asap_available?
      asap_window.present?
    end

    # --- Scheduled branch -------------------------------------------
    #
    # Days with at least one scheduled (non-ASAP) window. Sorted by
    # date ascending; the `hoy` day appears first only when it still has
    # post-lead-time windows remaining today.
    def scheduled_days
      days.map do |day|
        scheduled = day.windows.reject { |w| w.kind == :asap }
        next nil if scheduled.empty?

        OpenStruct.new(date: day.date, windows: scheduled)
      end.compact
    end

    def any_scheduled?
      scheduled_days.any?
    end

    def default_scheduled_day
      scheduled_days.first
    end

    # --- View helpers ------------------------------------------------
    def day_label(date)
      today = Date.current
      return I18n.t("storefronts.checkout.schedule.today_chip") if date == today
      return I18n.t("storefronts.checkout.schedule.tomorrow_chip") if date == today + 1.day

      DAY_SHORT[date.wday]
    end

    def day_number(date)
      date.day
    end

    def window_count_label(scheduled_day)
      I18n.t("storefronts.checkout.schedule.window_count", count: scheduled_day.windows.size)
    end

    # Computes the initial value of the hidden `delivery_window_id`
    # field — the first window we'd expect to be selected on render:
    #   - same_day → ASAP (if available)
    #   - advance  → first window of the first scheduled day
    #   - both     → ASAP if today is open, otherwise first scheduled window
    def default_selected_id
      return selected_id if selected_id.present?

      if (mode == "same_day" || mode == "both") && asap_available?
        asap_window.id
      elsif any_scheduled?
        default_scheduled_day.windows.first.id
      end
    end

    # Initial branch — "hoy" (ASAP) or "despues" (scheduled).
    def default_branch
      if mode == "same_day"
        "hoy"
      elsif mode == "advance"
        "despues"
      else
        asap_available? ? "hoy" : "despues"
      end
    end

    def show_segmented?
      mode == "both" && (asap_available? || any_scheduled?)
    end

    def show_hoy_branch?
      mode != "advance"
    end

    def show_despues_branch?
      mode != "same_day"
    end
  end
end
