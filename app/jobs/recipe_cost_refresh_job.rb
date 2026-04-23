# Async cost-cache refresh. Triggered from Ingredient, RecipeComponent,
# and Recipe callbacks whenever a change invalidates an upstream cost
# calculation. Fans out through Recipes::DependencyGraph so a price
# bump on "Harina de nixtamal" refreshes every recipe that uses it,
# directly or transitively.
#
# Idempotent: re-running is a no-op when nothing changed.
class RecipeCostRefreshJob < ApplicationJob
  queue_as :low

  # Accepts either a Recipe directly (`recipe:`) or a componentable that
  # needs fan-out (`componentable_type:`, `componentable_id:`). The two
  # entry points exist because Ingredient callbacks don't have a
  # single "parent recipe" — they hit every recipe that uses the
  # ingredient.
  def perform(recipe_id: nil, componentable_type: nil, componentable_id: nil)
    recipe_ids = gather_recipe_ids(recipe_id, componentable_type, componentable_id)

    recipe_ids.each do |id|
      recipe = Recipe.find_by(id: id)
      next unless recipe

      Recipes::CostCalculator.for(recipe: recipe)
    end
  end

  private

  def gather_recipe_ids(recipe_id, componentable_type, componentable_id)
    ids = Set.new

    if recipe_id
      ids << recipe_id
      ids.merge(dependents_of("Recipe", recipe_id))
    end

    if componentable_type && componentable_id
      ids.merge(dependents_of(componentable_type, componentable_id))
    end

    ids.to_a
  end

  def dependents_of(type, id)
    klass = type == "Recipe" ? Recipe : Ingredient
    record = klass.find_by(id: id)
    return [] unless record

    Recipes::DependencyGraph.recipes_depending_on(componentable: record).ids
  end
end
