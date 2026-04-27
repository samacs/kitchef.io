module Recipes
  # Operator-side stock projection for a single recipe on a given date.
  # Splits "what's actually sellable right now" from "what's currently
  # being cooked" so the recipe card can answer both questions at a
  # glance — the customer-facing badge just sums them, but the operator
  # wants to know whether the unit count comes from a fridge or a comal.
  #
  # Returns a Result struct with `available` (completed batches,
  # remaining units), `producing` (in-progress batches, remaining units),
  # and `total` (the sum). All values are BigDecimal in the recipe's
  # yield unit; views typically `.to_i` for the operator label.
  class StockSummary < ApplicationService
    Result = Struct.new(:available, :producing, :total, keyword_init: true) do
      def any?
        total.positive?
      end

      def producing?
        producing.positive?
      end

      def available?
        available.positive?
      end
    end

    option :account
    option :recipe
    option :on_date, default: -> { Date.current }

    def call
      batches = account.batches
        .active
        .where(recipe_id: recipe.id)
        .where("available_from <= ? AND available_until >= ?", on_date, on_date)

      available = sum_remaining(batches.where(state: "completed"))
      producing = sum_remaining(batches.where(state: "in_progress"))

      Result.new(
        available: available,
        producing: producing,
        total:     available + producing
      )
    end

    private

    def sum_remaining(scope)
      scope.sum { |b| [ b.units_remaining, BigDecimal(0) ].max }
    end
  end
end
