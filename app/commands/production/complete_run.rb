module Production
  # Marks an in-progress run as completed and reconciles `actual_quantity`
  # if the operator cooked fewer (or more) units than planned. The
  # difference is restocked (negative diff = restock back; positive
  # diff = take more from inventory). Idempotent on a run already in
  # `completed`.
  class CompleteRun < ApplicationCommand
    option :run
    option :actual_quantity, optional: true

    def call
      return failure([ "transition_not_allowed" ]) unless run.aasm.may_fire_event?(:complete)

      ActiveRecord::Base.transaction do
        actual = parse_quantity(actual_quantity) || run.actual_quantity
        diff = actual.to_d - run.planned_quantity.to_d

        if diff != 0
          adjust_consumption!(diff)
        end

        run.actual_quantity = actual
        run.save!
        run.complete!
      end

      success(run)
    end

    private

    # Reconcile inventory when the operator cooked something different
    # from the planned amount. We rebuild the consumption delta by
    # multiplying each existing consumption row by `(diff / planned)` —
    # negative means we over-consumed and need to restock the
    # difference; positive means we need to deduct more.
    def adjust_consumption!(diff)
      return if run.planned_quantity.to_d.zero?
      ratio = diff.to_d / run.planned_quantity.to_d

      run.consumptions.each do |consumption|
        ingredient = consumption.consumable
        next unless ingredient.is_a?(Ingredient)

        delta = (consumption.quantity_consumed.to_d * ratio).abs
        next if delta.zero?

        if diff.negative?
          ingredient.restock!(
            quantity:        delta,
            unit:            consumption.unit,
            source:          "production_cancel",
            source_record:   run,
            unit_cost_cents: consumption.cost_cents_at_consumption,
            note:            "Ajuste por completar con menos unidades"
          )
        else
          ingredient.deplete!(
            quantity:        delta,
            unit:            consumption.unit,
            source:          "production_deplete",
            source_record:   run,
            unit_cost_cents: ingredient.unit_cost_cents,
            note:            "Ajuste por completar con más unidades"
          )
        end
      end
    end

    def parse_quantity(raw)
      return nil if raw.blank?
      BigDecimal(raw.to_s)
    rescue ArgumentError, TypeError
      nil
    end
  end
end
