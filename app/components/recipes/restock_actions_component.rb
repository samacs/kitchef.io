module Recipes
  # Shown on the recipe edit page when inventory is enabled. Adapts to
  # two production models:
  #
  #   • **Batch-ahead** (default) — the recipe needs active batches to
  #     sell. Shows batch count, sub-recipe alerts, and batch CTAs.
  #
  #   • **Made-to-order** (`recipe.made_to_order?`) — the recipe is
  #     sellable as long as ingredients and sub-recipe batches are
  #     available. Shows producible-unit count (the bottleneck) and
  #     ingredient readiness.
  class RestockActionsComponent < ApplicationComponent
    option :recipe
    option :account

    Alert = Data.define(:name, :type, :stock_qty, :unit, :needed_qty, :status, :batch_path)

    def alerts
      @alerts ||= build_alerts
    end

    def made_to_order?
      recipe.made_to_order?
    end

    def available_units
      @available_units ||= if made_to_order?
        producible_units
      elsif recipe.is_saleable?
        batch_units
      else
        BigDecimal("0")
      end
    end

    def has_stock?
      available_units.positive?
    end

    def has_pending_sub_recipes?
      alerts.any? { |a| a.type == :sub_recipe }
    end

    def needs_production?
      recipe.is_saleable? && !has_stock? && !made_to_order?
    end

    def render?
      return false unless account.inventory_enabled? && recipe.persisted?

      if made_to_order?
        true
      else
        alerts.any? || needs_production?
      end
    end

    private

    def build_alerts
      items = []
      items.concat(ingredient_alerts)
      items.concat(sub_recipe_alerts) unless made_to_order? && has_all_sub_recipe_batches?
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

    def batch_units
      account.batches
        .active
        .where(recipe_id: recipe.id)
        .available_on(Date.current)
        .sum(&:units_remaining)
    end

    def producible_units
      Recipes::ProducibleUnits.call(recipe: recipe, account: account)
    end

    def available_batch_units(sub_recipe)
      account.batches
        .active
        .where(recipe_id: sub_recipe.id)
        .available_on(Date.current)
        .sum(&:units_remaining)
    end

    def has_all_sub_recipe_batches?
      recipe.components.where(componentable_type: "Recipe").reject(&:is_byproduct?).all? do |comp|
        available_batch_units(comp.componentable).positive?
      end
    end

    def convert_to_canonical(quantity, from_unit, to_unit)
      Recipes::UnitConverter.convert(quantity: quantity, from: from_unit, to: to_unit)
    rescue Recipes::UnitConverter::IncompatibleUnits
      quantity
    end
  end
end
