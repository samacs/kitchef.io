module Production
  # Walks a recipe's component tree and deducts the per-batch ingredient
  # quantities from `Ingredient#stock_quantity`. Writes a RunConsumption
  # row per leaf ingredient so the run carries its own snapshot of what
  # was used (and at what cost) — future edits to the recipe do not
  # retroactively rewrite the run.
  #
  # When the recipe is composed of sub-recipes (Phase 7), the walk
  # continues into those sub-recipes and deducts from their leaf
  # ingredients, scaled by how much of the parent's yield the run
  # produces. We do NOT track sub-recipe stock as first-class inventory
  # in v1 — see "recipe yield depletion" deferral in the plan.
  class DepleteIngredients < ApplicationService
    option :run

    def call
      Recipe.transaction do
        ingredient_totals.each do |ingredient_id, agg|
          ingredient = ingredient_for(ingredient_id)
          next if ingredient.nil?

          run.consumptions.create!(
            consumable:    ingredient,
            quantity_consumed: agg[:quantity],
            unit:          ingredient.unit,
            cost_cents_at_consumption: agg[:cost_cents]
          )

          ingredient.deplete!(
            quantity:      agg[:quantity],
            unit:          ingredient.unit,
            source:        "production_deplete",
            source_record: run,
            unit_cost_cents: ingredient.unit_cost_cents
          )
        end
      end
    end

    private

    # Aggregate totals per ingredient. Walking the tree iteratively
    # rather than recursively because we collect *quantities* in the
    # ingredient's canonical unit and roll them up — a sub-recipe used
    # twice contributes twice; a leaf ingredient referenced by both a
    # sub-recipe and the parent rolls up to a single entry.
    def ingredient_totals
      totals = Hash.new { |h, k| h[k] = { quantity: BigDecimal("0"), cost_cents: 0 } }
      walk(run.recipe, batch_units(run)) do |ingredient, qty_in_canonical|
        totals[ingredient.id][:quantity] += qty_in_canonical
        totals[ingredient.id][:cost_cents] = ingredient.unit_cost_cents
      end
      totals
    end

    # batch_units = how many "units of the parent recipe" the operator
    # is producing. For a recipe with `yield_quantity = 24` (servings)
    # and `planned_quantity = 12`, the run is half a batch — components
    # scale by 0.5.
    def batch_units(run)
      yld = run.recipe.yield_quantity.to_d
      return BigDecimal("0") if yld.zero?
      run.planned_quantity.to_d / yld
    end

    # Recursive depth-first walk into the component tree. Yields each
    # leaf ingredient with the quantity in the ingredient's canonical
    # unit, scaled by the multiplier coming down the recursion.
    def walk(recipe, multiplier, &block)
      recipe.components.each do |component|
        case component.componentable_type
        when "Ingredient"
          ingredient = component.componentable
          next if ingredient.nil?
          qty_in_canonical = Recipes::UnitConverter.convert(
            quantity: component.quantity.to_d,
            from:     component.unit,
            to:       ingredient.unit
          )
          yield ingredient, qty_in_canonical * multiplier
        when "Recipe"
          child = component.componentable
          next if child.nil?
          # Convert the parent's "I want N of the child's yield-unit"
          # into a multiplier on the child's component tree.
          qty_in_child_yield_unit = Recipes::UnitConverter.convert(
            quantity: component.quantity.to_d,
            from:     component.unit,
            to:       child.yield_unit
          )
          ratio = qty_in_child_yield_unit / child.yield_quantity.to_d
          walk(child, multiplier * ratio, &block)
        end
      end
    rescue Recipes::UnitConverter::IncompatibleUnits
      # Belt-and-suspenders — RecipeComponent already validates
      # compatibility at save time, so an IncompatibleUnits here means
      # the recipe was edited inconsistently. Skip the offending leaf
      # so the rest of the run still depletes.
    end

    def ingredient_for(id)
      run.account.ingredients.find_by(id: id)
    end
  end
end
