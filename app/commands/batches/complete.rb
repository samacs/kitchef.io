module Batches
  # Marks an in-progress batch as completed and reconciles
  # `actual_quantity` if the operator cooked fewer (or more) units than
  # planned. The difference is restocked (negative diff = restock back;
  # positive diff = take more from inventory). Idempotent on a batch
  # already in `completed`.
  class Complete < ApplicationCommand
    option :batch
    option :actual_quantity, optional: true

    def call
      return failure([ "transition_not_allowed" ]) unless batch.aasm.may_fire_event?(:complete)

      ActiveRecord::Base.transaction do
        actual = parse_quantity(actual_quantity) || batch.actual_quantity
        diff = actual.to_d - batch.planned_quantity.to_d

        if diff != 0
          adjust_consumption!(diff)
        end

        batch.actual_quantity = actual
        batch.save!
        batch.complete!
      end

      success(batch)
    end

    private

    def adjust_consumption!(diff)
      return if batch.planned_quantity.to_d.zero?
      ratio = diff.to_d / batch.planned_quantity.to_d

      batch.consumptions.each do |consumption|
        ingredient = consumption.consumable
        next unless ingredient.is_a?(Ingredient)

        delta = (consumption.quantity_consumed.to_d * ratio).abs
        next if delta.zero?

        if diff.negative?
          ingredient.restock!(
            quantity:        delta,
            unit:            consumption.unit,
            source:          "production_cancel",
            source_record:   batch,
            unit_cost_cents: consumption.cost_cents_at_consumption,
            note:            "Ajuste por completar con menos unidades"
          )
        else
          ingredient.deplete!(
            quantity:        delta,
            unit:            consumption.unit,
            source:          "production_deplete",
            source_record:   batch,
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
