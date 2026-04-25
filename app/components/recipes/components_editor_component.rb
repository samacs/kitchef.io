module Recipes
  # Whole "Componentes" block on the recipe edit page. Lists every
  # component as a row with quantity + unit + name + line cost, plus a
  # picker at the bottom that surfaces ingredients (always safe) and
  # recipes (filtered through Recipes::DependencyGraph to hide anything
  # that would cycle).
  #
  # Row markup itself lives in the `recipes/_components_rows` partial so
  # RecipesController#update can swap it back in via turbo-stream after
  # autosave — that's how new rows pick up their persisted IDs and stop
  # duplicating on subsequent saves.
  class ComponentsEditorComponent < ApplicationComponent
    option :recipe
    option :form

    def pickable_ingredients
      recipe.account.ingredients.kept.includes(:category).order(:category_id, :name)
    end

    # Recipes that can be safely added as a component without cycling.
    # Uses the model scope that filters out `recipe` itself and every
    # recipe whose tree already reaches back to it.
    def pickable_recipes
      return Recipe.none unless recipe.persisted?

      recipe.account.recipes
        .merge(Recipe.usable_as_component_for(recipe))
        .order(:name)
    end
  end
end
