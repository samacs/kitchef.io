module Batches
  # Counterpart to DepleteIngredients. Reads the batch's existing
  # BatchConsumption rows and reverses each one — restock the
  # ingredient by exactly what was consumed, so canceling a batch
  # leaves inventory in the same state as if the batch had never
  # happened.
  #
  # Cost basis comes from the snapshot in `cost_cents_at_consumption`,
  # not the ingredient's current price, so the audit trail stays
  # consistent: −X kg deplete at $30/kg, +X kg restock at $30/kg, even
  # if the operator's bought a more expensive lot since.
  class RestockIngredients < ApplicationService
    option :batch

    def call
      Recipe.transaction do
        batch.consumptions.each do |consumption|
          ingredient = consumption.consumable
          next unless ingredient.is_a?(Ingredient)

          ingredient.restock!(
            quantity:        consumption.quantity_consumed,
            unit:            consumption.unit,
            source:          "production_cancel",
            source_record:   batch,
            unit_cost_cents: consumption.cost_cents_at_consumption
          )
        end
        batch.consumptions.destroy_all
      end
    end
  end
end
