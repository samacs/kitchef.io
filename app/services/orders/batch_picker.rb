module Orders
  # For a given recipe + delivery date + quantity, returns the oldest
  # active batch that has enough remaining units to fulfill the order
  # item. Used by Orders::Place and the storefront re-check at submit
  # time.
  #
  # Returns the Batch or nil. The caller decides what to do when nil —
  # accept (warn policy) or reject (block policy).
  class BatchPicker < ApplicationService
    option :account
    option :recipe
    option :delivery_date
    option :quantity

    def call
      candidates = account.batches
        .active
        .where(recipe_id: recipe.id)
        .where("available_from <= ? AND available_until >= ?", delivery_date, delivery_date)
        .order(:cooked_on, :id)

      qty_needed = BigDecimal(quantity.to_s)

      candidates.find do |batch|
        batch.units_remaining >= qty_needed
      end
    end

    # Convenience for the storefront menu — total available units across
    # ALL active batches for a given recipe + date. Used to render
    # "Quedan N" / "Agotado" badges.
    def self.available_units(account:, recipe:, on_date:)
      batches = account.batches
        .active
        .where(recipe_id: recipe.id)
        .where("available_from <= ? AND available_until >= ?", on_date, on_date)

      batches.sum(&:units_remaining)
    end
  end
end
