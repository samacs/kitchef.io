module Recipes
  # Computes and persists `cost_delta_cents` for every inventory-linked
  # RecipeOption under a given recipe. Called by RecipeCostRefreshJob
  # after the recipe's own cost cache is updated.
  #
  # For Ingredient-linked options: cost = converted_qty * unit_cost_cents.
  # For Recipe-linked options: cost = (converted_qty / yield) * recipe cost.
  class OptionCostCalculator < ApplicationService
    option :recipe

    def call
      groups = recipe.option_groups.kept.includes(options: :componentable)

      groups.each do |group|
        group.options.each do |opt|
          next unless opt.inventory_linked?

          cents = cost_cents_for(opt)
          next if opt.cost_delta_cents == cents

          opt.update_columns(cost_delta_cents: cents, updated_at: Time.current)
        end
      end
    end

    private

    def cost_cents_for(opt)
      case opt.componentable
      when Ingredient then ingredient_cost(opt)
      when Recipe     then recipe_cost(opt)
      else 0
      end
    end

    def ingredient_cost(opt)
      ing = opt.componentable
      qty = Recipes::UnitConverter.convert(quantity: opt.quantity, from: opt.unit, to: ing.unit)
      (qty * BigDecimal(ing.unit_cost_cents.to_s)).to_i
    rescue Recipes::UnitConverter::IncompatibleUnits
      0
    end

    def recipe_cost(opt)
      child = opt.componentable
      child_cost = child.cost_cents_cached.to_i
      return 0 if child_cost.zero? || child.yield_quantity.to_d.zero?

      qty = Recipes::UnitConverter.convert(quantity: opt.quantity, from: opt.unit, to: child.yield_unit)
      ratio = qty / BigDecimal(child.yield_quantity.to_s)
      (ratio * BigDecimal(child_cost.to_s)).to_i
    rescue Recipes::UnitConverter::IncompatibleUnits
      0
    end
  end
end
