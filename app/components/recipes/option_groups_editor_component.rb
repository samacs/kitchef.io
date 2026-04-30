module Recipes
  class OptionGroupsEditorComponent < ApplicationComponent
    option :recipe
    option :form

    def option_groups
      recipe.option_groups.kept.order(:position, :id)
    end

    def kind_options
      RecipeOptionGroup::KINDS.keys.map do |k|
        [ I18n.t("recipe.option_group_kinds.#{k}"), k ]
      end
    end

    def removable_components
      recipe.components.includes(:componentable).where(componentable_type: "Ingredient").order(:position)
    end

    def composable?
      recipe.account.composable_recipes?
    end

    def pickable_ingredients
      return [] unless composable?
      recipe.account.ingredients.kept.includes(:category).order(:name)
    end

    def pickable_recipes_for_options
      return [] unless composable?
      return [] unless recipe.persisted?
      recipe.account.recipes
        .merge(Recipe.usable_as_component_for(recipe))
        .internal
        .order(:name)
    end

    def unit_options_for(componentable)
      case componentable
      when Ingredient then Ingredient::UNITS
      when Recipe     then Recipe::YIELD_UNITS
      else Ingredient::UNITS
      end
    end

    def componentable_candidates_json
      items = []
      pickable_ingredients.each do |ing|
        items << { type: "Ingredient", id: ing.id, name: ing.name, unit: ing.unit,
                   units: Ingredient::UNITS }
      end
      pickable_recipes_for_options.each do |r|
        items << { type: "Recipe", id: r.id, name: r.name, unit: r.yield_unit,
                   units: Recipe::YIELD_UNITS }
      end
      items.to_json
    end

    def format_delta(cents)
      return nil if cents.to_i.zero?
      money = Money.new(cents.abs, "MXN")
      formatted = helpers.humanized_money_with_symbol(money)
      cents.positive? ? "+#{formatted}" : "-#{formatted}"
    end
  end
end
