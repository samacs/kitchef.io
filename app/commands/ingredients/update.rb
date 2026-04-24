module Ingredients
  # Updates an ingredient. The `after_commit` hook on Ingredient triggers
  # `RecipeCostRefreshJob` when `unit_cost_cents_changed?` — the UI layer
  # consumes the DependencyGraph separately to surface an impact panel
  # to the operator.
  class Update < ApplicationCommand
    option :ingredient
    option :params

    def call
      if ingredient.update(params.to_h)
        success(ingredient)
      else
        Result.new(success: false, object: ingredient, errors: ingredient.errors)
      end
    end
  end
end
