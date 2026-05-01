module Storefronts
  class RecipeOptionsComponent < ApplicationComponent
    option :recipe

    option :account, optional: true

    def option_groups
      recipe.option_groups.kept.includes(options: :componentable).order(:position, :id)
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

    def inventory_enabled?
      account&.inventory_enabled? || false
    end

    def stock_label_for(opt)
      return nil unless inventory_enabled?
      return nil unless opt.inventory_linked?
      return nil unless opt.componentable.is_a?(Ingredient)

      qty = opt.componentable.stock_quantity.to_d
      return I18n.t("storefronts.recipe.options.out_of_stock") if qty <= 0

      nil
    end

    def render?
      option_groups.any? || removable_components.any?
    end
  end
end
