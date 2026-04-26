module Production
  # Counterpart to DepleteIngredients. Reads the run's existing
  # RunConsumption rows and reverses each one — restock the ingredient
  # by exactly what was consumed, so canceling an in-progress run
  # leaves inventory in the same state as if the run had never
  # happened.
  #
  # Cost basis comes from the snapshot in `cost_cents_at_consumption`,
  # not the ingredient's current price, so the audit trail stays
  # consistent: -X kg deplete at $30/kg, +X kg restock at $30/kg, even
  # if the operator's bought a more expensive batch since.
  class RestockIngredients < ApplicationService
    option :run

    def call
      Recipe.transaction do
        run.consumptions.each do |consumption|
          ingredient = consumption.consumable
          next unless ingredient.is_a?(Ingredient)

          ingredient.restock!(
            quantity:        consumption.quantity_consumed,
            unit:            consumption.unit,
            source:          "production_cancel",
            source_record:   run,
            unit_cost_cents: consumption.cost_cents_at_consumption
          )
        end
        run.consumptions.destroy_all
      end
    end
  end
end
