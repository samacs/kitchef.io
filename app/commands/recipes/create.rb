module Recipes
  # Creates a saleable recipe in simple mode. Applies the invisible-in-the-form
  # defaults server-side so the Phase 2B form can stay focused on the four
  # fields the operator actually fills in (name, price, category, description)
  # plus the photo upload.
  #
  # On failure, returns the invalid recipe as `result.object` so the controller
  # can re-render the form with the submitted values.
  class Create < ApplicationCommand
    option :account
    option :params

    SIMPLE_DEFAULTS = {
      is_saleable:           true,
      is_published:          false,
      yield_quantity:        1,
      yield_unit:            "piece",
      target_margin_percent: 60
    }.freeze

    def call
      recipe = account.recipes.new(SIMPLE_DEFAULTS.merge(params.to_h))
      if recipe.save
        success(recipe)
      else
        Result.new(success: false, object: recipe, errors: recipe.errors)
      end
    end
  end
end
