module Ingredients
  # Single row in the ingredients index table. Parallels Clients::RowComponent
  # — name + unit + current price + relative last-updated + count of
  # recipes using it + quick edit/delete actions.
  class RowComponent < ApplicationComponent
    option :ingredient

    def category_label
      ingredient.category&.name
    end

    def unit_label
      I18n.t("units.#{ingredient.unit}", default: ingredient.unit)
    end

    def price_label
      helpers.humanized_money_with_symbol(ingredient.unit_cost)
    end

    def price_per_unit_label
      "#{price_label} / #{unit_label}"
    end

    def updated_at_label
      return nil if ingredient.price_updated_at.blank?

      helpers.l(ingredient.price_updated_at.to_date, format: :long)
    end

    def used_by_count
      ingredient.recipe_components.size
    end

    def edit_path
      helpers.edit_ingredient_path(ingredient)
    end
  end
end
