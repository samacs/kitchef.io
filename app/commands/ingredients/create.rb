module Ingredients
  # Creates an ingredient scoped to the account. Price input arrives as
  # a decimal (MXN pesos) via the form's `unit_cost` attribute; money-rails
  # converts it to cents. Returns the invalid record on failure so the
  # controller re-renders the form with submitted values.
  class Create < ApplicationCommand
    option :account
    option :params

    def call
      ingredient = account.ingredients.new(params.to_h)
      if ingredient.save
        success(ingredient)
      else
        Result.new(success: false, object: ingredient, errors: ingredient.errors)
      end
    end
  end
end
