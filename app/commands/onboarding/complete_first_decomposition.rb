module Onboarding
  # Atomic: saves the proposed decomposition AND flips
  # `settings.use_composable_recipes` to true. Either both or neither.
  # The flip sits behind a successful save so an operator who submits
  # a malformed form doesn't end up in advanced mode with zero real
  # components to show for it.
  class CompleteFirstDecomposition < ApplicationCommand
    option :account
    option :recipe
    option :components_attributes

    def call
      ActiveRecord::Base.transaction do
        recipe.components_attributes = components_attributes
        unless recipe.save
          raise ActiveRecord::Rollback
        end

        settings = account.settings
        settings.use_composable_recipes = true
        settings.composable_recipes_unlocked_at = Time.current
        account.settings = settings
        unless account.save
          raise ActiveRecord::Rollback
        end

        Recipes::CostCalculator.for(recipe: recipe)
        return success(recipe)
      end

      Result.new(success: false, object: recipe, errors: recipe.errors)
    end
  end
end
