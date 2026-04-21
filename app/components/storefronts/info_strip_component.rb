module Storefronts
  # Horarios + Entregas two-card strip below the hero. Reads from the
  # account's public_profile; skips sections gracefully when a kitchen
  # hasn't configured them yet.
  class InfoStripComponent < ApplicationComponent
    option :storefront
    option :ordering_hours  # Storefronts::OrderingHours::Result

    delegate :public_profile, to: :storefront
    delegate :phone, :whatsapp, :delivery_zones_list, :city, to: :public_profile

    DAY_LABELS = { 1 => "Lunes", 2 => "Martes", 3 => "Miércoles", 4 => "Jueves",
                   5 => "Viernes", 6 => "Sábado", 0 => "Domingo" }.freeze

    def schedule_rows
      raw = public_profile.ordering_hours.to_s
      return nil if raw.blank?

      parsed = JSON.parse(raw) rescue {}
      DAY_LABELS.map do |wday, label|
        entry = parsed[wday.to_s]
        row = if entry.is_a?(Hash) && entry["open"] && entry["close"]
          "#{entry["open"]}–#{entry["close"]}"
        else
          "Cerrado"
        end
        [ label, row ]
      end
    end

    def any_zones?
      delivery_zones_list.any?
    end
  end
end
