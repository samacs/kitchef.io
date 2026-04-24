module Recipes
  # Given an Ingredient (or a set of recipes via :recipe_ids), rescale
  # each affected recipe's sale price so its margin matches its own
  # `target_margin_percent`. Leaves internal recipes (`is_saleable:
  # false`) alone — they have no sale price to adjust.
  #
  # Returns the count of recipes whose price changed.
  class RescaleForMargin < ApplicationCommand
    option :ingredient,  optional: true
    option :recipe_ids,  optional: true

    def call
      recipes = load_recipes
      changed = 0

      ActiveRecord::Base.transaction do
        recipes.each do |recipe|
          next unless recipe.is_saleable?
          cost_cents = Recipes::CostCalculator.for(recipe: recipe).cents
          next if cost_cents.zero?

          target_margin = recipe.target_margin_percent.to_i
          next if target_margin >= 100

          # new_price such that (new_price - cost) / new_price == target_margin/100
          # → new_price = cost / (1 - target_margin/100)
          divisor = 1.0 - (target_margin / 100.0)
          new_price_cents = (cost_cents / divisor).round

          if new_price_cents != recipe.sale_price_cents
            recipe.update_columns(
              sale_price_cents: new_price_cents,
              updated_at:       Time.current
            )
            changed += 1
          end
        end
      end

      success(changed)
    end

    private

    def load_recipes
      return Recipe.where(id: recipe_ids) if recipe_ids.present?
      return Recipes::DependencyGraph.recipes_depending_on(componentable: ingredient) if ingredient

      Recipe.none
    end
  end
end
