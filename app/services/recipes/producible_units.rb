module Recipes
  # For a made-to-order recipe, calculates how many units the operator
  # can produce from current ingredient stock. Returns the minimum
  # across all components (the bottleneck ingredient).
  #
  # Sub-recipe components use available batch units; ingredient
  # components use on-hand stock converted to recipe-component units.
  class ProducibleUnits < ApplicationService
    option :recipe
    option :account

    def call
      return BigDecimal("0") if recipe.components.empty?

      limits = recipe.components.includes(:componentable).reject(&:is_byproduct?).map do |comp|
        case comp.componentable
        when Ingredient then ingredient_limit(comp)
        when Recipe     then sub_recipe_limit(comp)
        else BigDecimal("0")
        end
      end

      return BigDecimal("0") if limits.empty?

      [ limits.min.floor, BigDecimal("0") ].max
    end

    private

    def ingredient_limit(comp)
      ing = comp.componentable
      return BigDecimal("0") if comp.quantity.to_d.zero?

      on_hand = convert(ing.stock_quantity, ing.unit, comp.unit)
      on_hand / comp.quantity
    rescue Recipes::UnitConverter::IncompatibleUnits
      BigDecimal("0")
    end

    def sub_recipe_limit(comp)
      sub = comp.componentable
      return BigDecimal("0") if comp.quantity.to_d.zero?

      available = account.batches
        .active
        .where(recipe_id: sub.id)
        .available_on(Date.current)
        .sum(&:units_remaining)

      return BigDecimal("Infinity") if available.to_d.zero? && comp.quantity.to_d.zero?

      on_hand = convert(available, sub.yield_unit, comp.unit)
      on_hand / comp.quantity
    rescue Recipes::UnitConverter::IncompatibleUnits
      BigDecimal("0")
    end

    def convert(quantity, from, to)
      Recipes::UnitConverter.convert(quantity: quantity, from: from, to: to)
    end
  end
end
