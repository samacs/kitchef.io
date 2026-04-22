module Production
  # One row in the weekly delivery-slot grid. Given a weekday number
  # (0–6, Sunday=0 per Ruby `wday`) and the current slot (may be nil),
  # renders the start/end time pickers, capacity input, and the live
  # fill indicator for the current week. v1: one slot per weekday.
  class SlotRowComponent < ApplicationComponent
    DAY_LABELS = {
      0 => "Domingo",
      1 => "Lunes",
      2 => "Martes",
      3 => "Miércoles",
      4 => "Jueves",
      5 => "Viernes",
      6 => "Sábado"
    }.freeze

    option :day_of_week
    option :slot,       default: -> { nil }
    option :fill_level, default: -> { 0 }

    def day_label
      DAY_LABELS.fetch(day_of_week)
    end

    def closed?
      slot.nil?
    end

    def capacity_label
      return I18n.t("delivery_slots.capacity.unlimited") if slot.nil? || slot.capacity.blank?

      I18n.t("delivery_slots.capacity.display", filled: fill_level, total: slot.capacity)
    end

    def start_hhmm = slot&.start_time_hhmm
    def end_hhmm   = slot&.end_time_hhmm
    def capacity   = slot&.capacity
  end
end
