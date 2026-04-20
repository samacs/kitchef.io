module OrdersHelper
  # Quantity-input step/min per recipe yield_unit. Pieces, servings, and
  # gram/milliliter units are always whole numbers in practice — the
  # operator types "2" for dos tamales or "250" for a cuarto de carne,
  # never "1.002". Only bulk weight/volume (kg, l) benefits from a
  # decimal step so half-kilos and 1.5L jugs work naturally.
  QUANTITY_RULES = {
    "piece"   => { step: "1",   min: "1"   },
    "serving" => { step: "1",   min: "1"   },
    "g"       => { step: "1",   min: "1"   },
    "ml"      => { step: "1",   min: "1"   },
    "kg"      => { step: "0.1", min: "0.1" },
    "l"       => { step: "0.1", min: "0.1" }
  }.freeze
  DEFAULT_QUANTITY_RULE = { step: "1", min: "1" }.freeze

  def quantity_rule_for(unit)
    QUANTITY_RULES.fetch(unit.to_s, DEFAULT_QUANTITY_RULE)
  end

  # Natural production-flow order. `primary_transition_for` walks this
  # list and returns the first event that's permitted from the order's
  # current state — that's the card's main next-step CTA. `mark_paid`
  # intentionally sits last so "Iniciar producción" wins over "Marcar
  # pagado" when both are available (the common case from `:confirmed`).
  # `ship` comes before `deliver` so a delivery-type order in `ready`
  # state picks "Marcar en camino" as its primary; pickup-type orders
  # don't qualify for `ship` (the AASM guard returns false) and fall
  # through to `deliver`. `mark_paid` stays last so the happy-path
  # transition wins whenever both are available.
  PRIMARY_EVENT_ORDER = %i[confirm start_production mark_ready ship deliver mark_paid].freeze

  def primary_transition_for(order)
    PRIMARY_EVENT_ORDER.find { |event| order.aasm.may_fire_event?(event) }
  end
end
