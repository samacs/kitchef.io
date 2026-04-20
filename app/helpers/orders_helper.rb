module OrdersHelper
  # Natural production-flow order. `primary_transition_for` walks this
  # list and returns the first event that's permitted from the order's
  # current state — that's the card's main next-step CTA. `mark_paid`
  # intentionally sits last so "Iniciar producción" wins over "Marcar
  # pagado" when both are available (the common case from `:confirmed`).
  PRIMARY_EVENT_ORDER = %i[confirm start_production mark_ready deliver mark_paid].freeze

  def primary_transition_for(order)
    PRIMARY_EVENT_ORDER.find { |event| order.aasm.may_fire_event?(event) }
  end
end
