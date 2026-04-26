class RunConsumption < ApplicationRecord
  # Ledger row written when a ProductionRun deducts an ingredient (or a
  # sub-recipe) from inventory. Snapshots `quantity_consumed` and
  # `cost_cents_at_consumption` at run-start time so a later edit to
  # the recipe can't retroactively rewrite the run's cost basis. Same
  # invariant as OrderItem#unit_cost_cents.
  #
  # `consumable` is polymorphic — Ingredient for raw deductions, Recipe
  # reserved for a future "recipe yield depletion" pass that pulls from
  # a base-recipe stock instead of recomputing from leaves.

  belongs_to :production_run
  belongs_to :consumable, polymorphic: true

  validates :quantity_consumed, numericality: true
  validates :unit, presence: true
  validates :cost_cents_at_consumption,
    numericality: { greater_than_or_equal_to: 0 }
end
