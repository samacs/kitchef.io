module Storefronts
  # Inline chip that shows whether the kitchen is accepting orders right
  # now. When open: "Aceptando pedidos · Vie 9:00–18:00". When closed:
  # "Abrimos el jueves 9:00". Falls back to a soft "Por encargo · WhatsApp"
  # when the account has no schedule configured.
  #
  # Submissions are STILL accepted when closed (the customer might be
  # pre-ordering for tomorrow); this chip only sets expectations.
  class OrderingHoursChipComponent < ApplicationComponent
    option :result  # Storefronts::OrderingHours::Result

    def label
      Storefronts::OrderingHours.chip_label(result)
    end

    def open_now?
      result&.open_now?
    end
  end
end
