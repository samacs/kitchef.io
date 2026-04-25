module Storefronts
  class RecipeOptionsComponent < ApplicationComponent
    option :recipe

    def option_groups
      recipe.option_groups.kept.includes(:options).order(:position, :id)
    end

    def removable_components
      recipe.components.includes(:componentable)
            .where(componentable_type: "Ingredient", is_removable: true)
            .order(:position)
    end

    def options_for(group)
      group.options.kept.order(:position, :id)
    end

    def format_delta(cents)
      return nil if cents.to_i.zero?
      money = Money.new(cents.abs, "MXN")
      formatted = helpers.humanized_money_with_symbol(money)
      cents.positive? ? "+#{formatted}" : "-#{formatted}"
    end

    def render?
      option_groups.any? || removable_components.any?
    end
  end
end
