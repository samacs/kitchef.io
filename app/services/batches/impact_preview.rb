module Batches
  # Pre-flight calculation for the new-batch form. Walks the recipe's
  # component tree (same logic as DepleteIngredients) and reports per-
  # ingredient: how much this batch would consume, current stock, and
  # whether we'd go negative. Renders the educational warning row in
  # _impact_preview.html.erb so the operator sees "you'll need more
  # harina" BEFORE submit, not as a flash after the fact.
  #
  # Returns an array of structs ordered by severity (negatives first).
  Result = Data.define(:ingredient, :needed, :unit, :current_stock, :shortfall) do
    def shortage? = shortfall.to_d.positive?
  end

  class ImpactPreview < ApplicationService
    option :recipe
    option :quantity

    def call
      totals = totals_for(recipe, batch_units(recipe, quantity))
      results = totals.map do |id, agg|
        ingredient = recipe.account.ingredients.find_by(id: id)
        next nil if ingredient.nil?

        needed = agg[:quantity].to_d
        stock  = ingredient.stock_quantity.to_d
        shortfall = (needed - stock)
        shortfall = BigDecimal("0") if shortfall.negative?

        Result.new(ingredient: ingredient, needed: needed, unit: ingredient.unit,
                   current_stock: stock, shortfall: shortfall)
      end.compact

      results.sort_by { |r| [ r.shortage? ? 0 : 1, -r.shortfall.to_d ] }
    end

    private

    def totals_for(recipe, multiplier)
      totals = Hash.new { |h, k| h[k] = { quantity: BigDecimal("0") } }
      walk(recipe, multiplier) { |ing, qty| totals[ing.id][:quantity] += qty }
      totals
    end

    def batch_units(recipe, qty)
      yld = recipe.yield_quantity.to_d
      return BigDecimal("0") if yld.zero?
      BigDecimal(qty.to_s) / yld
    end

    def walk(recipe, multiplier, &block)
      recipe.components.each do |component|
        case component.componentable_type
        when "Ingredient"
          ingredient = component.componentable
          next if ingredient.nil?
          qty = Recipes::UnitConverter.convert(
            quantity: component.quantity.to_d,
            from:     component.unit,
            to:       ingredient.unit
          )
          yield ingredient, qty * multiplier
        when "Recipe"
          child = component.componentable
          next if child.nil?
          qty_child = Recipes::UnitConverter.convert(
            quantity: component.quantity.to_d,
            from:     component.unit,
            to:       child.yield_unit
          )
          ratio = qty_child / child.yield_quantity.to_d
          walk(child, multiplier * ratio, &block)
        end
      end
    rescue Recipes::UnitConverter::IncompatibleUnits
      # Skip mis-configured leaves; same convention as DepleteIngredients.
    end
  end
end
