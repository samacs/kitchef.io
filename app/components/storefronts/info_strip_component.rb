module Storefronts
  # Horarios + Entregas two-card strip below the hero. Reads schedule
  # data from the account's Schedule (weekly recurring windows only —
  # exceptions are per-date and don't make sense on a static summary).
  # Falls back to a single "Por encargo · WhatsApp" line when the
  # kitchen hasn't configured any schedule yet.
  class InfoStripComponent < ApplicationComponent
    option :storefront
    option :ordering_hours  # Storefronts::OrderingHours::Result

    delegate :public_profile, to: :storefront
    delegate :phone, :whatsapp, :delivery_zones_list, :city, to: :public_profile

    DAY_LABELS = { 1 => "Lunes", 2 => "Martes", 3 => "Miércoles", 4 => "Jueves",
                   5 => "Viernes", 6 => "Sábado", 0 => "Domingo" }.freeze

    def schedule_rows
      schedule = storefront.schedule
      return nil if schedule.nil? || schedule.availabilities.recurring.none?

      DAY_LABELS.map do |wday, label|
        windows = schedule.availabilities.recurring.for_wday(wday).order(:from_time)
        display = windows.empty? ? "Cerrado" : windows.map { |w| "#{w.from_time_hhmm}–#{w.to_time_hhmm}" }.join(" · ")
        [ label, display ]
      end
    end

    def any_zones?
      delivery_zones_list.any?
    end

    def payment_settings
      storefront.payment_settings
    end

    def any_payment_method?
      payment_settings.any_method_enabled?
    end
  end
end
