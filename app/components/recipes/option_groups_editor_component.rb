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

    def format_delta(cents)
      return nil if cents.to_i.zero?
      money = Money.new(cents.abs, "MXN")
      formatted = helpers.humanized_money_with_symbol(money)
      cents.positive? ? "+#{formatted}" : "-#{formatted}"
    end
  end
end
