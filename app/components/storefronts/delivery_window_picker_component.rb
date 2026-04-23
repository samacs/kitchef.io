module Storefronts
  # Customer-facing delivery-window picker. Replaces the free-text
  # date + HH:MM fields with a server-rendered list of available
  # windows (plus "ASAP" for same-day kitchens). The form posts a single
  # `delivery_window_id` field; `Storefronts::PlaceOrder` decodes it back
  # into a date + time pair via `Schedules::AvailableWindows.decode`.
  #
  # Falls back gracefully when the kitchen has no schedule yet: shows
  # a "Por encargo · coordina por WhatsApp" note instead of the picker.
  class DeliveryWindowPickerComponent < ApplicationComponent
    DAY_LABELS = %w[domingo lunes martes miércoles jueves viernes sábado].freeze
    DAY_SHORT  = %w[Dom Lun Mar Mié Jue Vie Sáb].freeze

    option :account
    option :precomputed_days, default: -> { nil }
    option :selected_id,      default: -> { nil }

    # Callers can pre-compute the windows (the checkout controller does
    # this so the view layer can disable the submit button when the
    # schedule is empty). Falls back to a fresh service call for any
    # caller that hasn't supplied one.
    def days
      @_days ||= precomputed_days || Schedules::AvailableWindows.for(account: account)
    end

    def any_windows?
      days.any? { |day| day.windows.any? }
    end

    def first_window_id
      days.flat_map(&:windows).first&.id
    end

    def selected?(window)
      return true if selected_id == window.id
      return true if selected_id.nil? && window.id == first_window_id

      false
    end

    def day_header(date)
      today = Date.current
      return I18n.t("storefronts.checkout.schedule.today") if date == today
      return I18n.t("storefronts.checkout.schedule.tomorrow") if date == today + 1.day

      short = DAY_SHORT[date.wday]
      "#{short} · #{date.day} de #{month_label(date)}"
    end

    def window_label(window)
      if window.kind == :asap
        I18n.t("storefronts.checkout.schedule.asap_label")
      else
        "#{window.from_time_hhmm}–#{window.to_time_hhmm}"
      end
    end

    def window_sub(window)
      return I18n.t("storefronts.checkout.schedule.asap_sub") if window.kind == :asap

      nil
    end

    private

    def month_label(date)
      I18n.t("date.month_names")[date.month]
    end
  end
end
