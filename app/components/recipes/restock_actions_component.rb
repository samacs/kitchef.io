module Recipes
  # Shown on the recipe edit page when inventory is enabled and the
  # recipe (or its sub-recipes) has stock issues. Lists which
  # ingredients are low/depleted and which batches need to be created,
  # with direct CTAs to the batch creation form.
  class RestockActionsComponent < ApplicationComponent
    option :recipe
    option :account

    Alert = Data.define(:name, :type, :stock_qty, :unit, :needed_qty, :status, :batch_path)

    def alerts
      @alerts ||= build_alerts
    end

    def render?
      account.inventory_enabled? && recipe.persisted? && alerts.any?
    end

    private

    def build_alerts
      items = []
      items.concat(ingredient_alerts)
      items.concat(sub_recipe_alerts)
      items
    end

    def ingredient_alerts
      recipe.components.includes(:componentable)
            .where(componentable_type: "Ingredient")
            .filter_map do |comp|
        ing = comp.componentable
        next unless ing

        needed = convert_to_canonical(comp.quantity, comp.unit, ing.unit)
        on_hand = ing.stock_quantity.to_d
        status = stock_status(on_hand, ing)

        next if status == :ok

        Alert.new(
          name:       ing.name,
          type:       :ingredient,
          stock_qty:  on_hand,
          unit:       ing.unit,
          needed_qty: needed,
          status:     status,
          batch_path: nil
        )
      end
    end

    def sub_recipe_alerts
      recipe.components.includes(:componentable)
            .where(componentable_type: "Recipe")
            .reject(&:is_byproduct?)
            .filter_map do |comp|
        sub = comp.componentable
        next unless sub

        available = available_batch_units(sub)
        status = available.positive? ? :ok : :needs_batch

        next if status == :ok

        Alert.new(
          name:       sub.name,
          type:       :sub_recipe,
          stock_qty:  available,
          unit:       sub.yield_unit,
          needed_qty: comp.quantity,
          status:     status,
          batch_path: "/batches/new?batch[recipe_id]=#{sub.id}"
        )
      end
    end

    def stock_status(on_hand, ingredient)
      return :depleted if on_hand <= 0
      return :low if ingredient.low_stock?
      :ok
    end

    def available_batch_units(sub_recipe)
      account.batches
        .active
        .where(recipe_id: sub_recipe.id)
        .available_on(Date.current)
        .sum(&:units_remaining)
    end

    def convert_to_canonical(quantity, from_unit, to_unit)
      Recipes::UnitConverter.convert(quantity: quantity, from: from_unit, to: to_unit)
    rescue Recipes::UnitConverter::IncompatibleUnits
      quantity
    end
  end
end
