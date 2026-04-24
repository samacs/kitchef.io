module Ingredients
  # Creates an ingredient scoped to the account. Price input arrives as
  # a decimal (MXN pesos) via the form's `unit_cost` attribute; money-rails
  # converts it to cents. Returns the invalid record on failure so the
  # controller re-renders the form with submitted values.
  class Create < ApplicationCommand
    option :account
    option :params

    def call
      attrs = params.to_h
      attrs[:category_id] ||= default_ingredient_category_id

      ingredient = account.ingredients.new(attrs)
      if ingredient.save
        success(ingredient)
      else
        Result.new(success: false, object: ingredient, errors: ingredient.errors)
      end
    end

    private

    def default_ingredient_category_id
      account.categories.for_kind(:ingredient).kept.order(:position, :name).pick(:id)
    end
  end
end
