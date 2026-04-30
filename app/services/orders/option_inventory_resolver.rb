module Orders
  # Given an order item's selected_options and the recipe's option groups,
  # resolves inventory-linked options into depletion tuples:
  # [{ ingredient:, quantity:, unit: }].
  #
  # For Recipe-type componentables, walks the component tree down to leaf
  # Ingredients so stock movements always land on concrete ingredients.
  #
  # Uniform mode only for now — each selected option contributes its
  # configured quantity once per order-item quantity unit.
  class OptionInventoryResolver < ApplicationService
    option :order_item

    Depletion = Data.define(:ingredient, :quantity, :unit)

    def call
      return [] if order_item.selected_options.blank?

      recipe = order_item.recipe
      groups = recipe.option_groups.kept.includes(options: :componentable).index_by(&:id)

      depletions = []

      order_item.selected_options.each do |group_key, selections|
        group = groups[group_key.to_i]
        next unless group

        Array(selections).each do |sel|
          opt_id = sel.is_a?(Hash) ? (sel[:id] || sel["id"]) : sel
          next if opt_id.blank?

          opt = group.options.detect { |o| o.id == opt_id.to_i }
          next unless opt&.inventory_linked?

          qty = opt.quantity * order_item.quantity

          case opt.componentable
          when Ingredient
            depletions << Depletion.new(
              ingredient: opt.componentable,
              quantity: qty,
              unit: opt.unit
            )
          when Recipe
            depletions.concat(expand_recipe(opt.componentable, qty, opt.unit))
          end
        end
      end

      depletions
    end

    private

    # Walks a sub-recipe's component tree to leaf ingredients, scaling
    # quantities by the ratio consumed. Mirrors the expansion pattern
    # in Recipes::CostCalculator#recipe_component_cents.
    def expand_recipe(child_recipe, qty_consumed, consumed_unit)
      return [] if child_recipe.yield_quantity.to_d.zero?

      begin
        qty_in_yield = Recipes::UnitConverter.convert(
          quantity: qty_consumed, from: consumed_unit, to: child_recipe.yield_unit
        )
      rescue Recipes::UnitConverter::IncompatibleUnits
        return []
      end

      ratio = qty_in_yield / child_recipe.yield_quantity.to_d

      child_recipe.components.includes(:componentable).flat_map do |comp|
        next [] if comp.is_byproduct?

        scaled_qty = comp.quantity * ratio

        case comp.componentable
        when Ingredient
          Depletion.new(
            ingredient: comp.componentable,
            quantity: scaled_qty,
            unit: comp.unit
          )
        when Recipe
          expand_recipe(comp.componentable, scaled_qty, comp.unit)
        else
          []
        end
      end
    end
  end
end
