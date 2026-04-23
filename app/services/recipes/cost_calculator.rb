module Recipes
  # Bottom-up cost resolution for a Recipe's component tree. Returns a
  # Money value in MXN. Writes back to `recipe.cost_cents_cached` at the
  # end so downstream reads (cost tree view, margin chip, shopping list
  # aggregation) are fast.
  #
  # Memoizes per-recipe within a single call so a deep tree with shared
  # bases (masa → used by tacos, quesadillas, sopes) stays O(nodes)
  # rather than O(paths).
  #
  # Handles the three leaf shapes:
  #   • Ingredient component — cost = converted_qty * ingredient.unit_cost
  #   • Recipe component     — cost = (converted_qty / yield_quantity) * recipe_total_cost
  #   • No components        — cost = 0 (nil in the cache column, rendered as "—")
  #
  # Silent on unit-conversion errors at calculate time: a component whose
  # unit doesn't match the componentable's canonical unit is counted as
  # zero cost and the form-layer validator warns the operator at save
  # time. We do not blow up the whole recipe cost over a single bad row.
  class CostCalculator < ApplicationService
    option :recipe
    option :memo, default: -> { {} }, optional: true

    def self.for(recipe:)
      call(recipe: recipe)
    end

    def call
      cents = total_cents_for(recipe)
      Money.new(cents, "MXN")
    end

    private

    # Walks the tree bottom-up. Each recipe visited has its
    # `cost_cents_cached` persisted so downstream reads (cost tree,
    # shopping list, margin chip) don't each pay the traversal cost.
    def total_cents_for(node)
      return memo[node.id] if memo.key?(node.id)

      components = node.components.to_a
      if components.empty?
        memo[node.id] = 0
        persist_cache(node, 0)
        return 0
      end

      total = components.sum { |c| component_cents(c) }
      memo[node.id] = total
      persist_cache(node, total)
      total
    end

    def component_cents(component)
      case component.componentable
      when Ingredient then ingredient_cents(component)
      when Recipe     then recipe_component_cents(component)
      else 0
      end
    end

    def ingredient_cents(component)
      ing = component.componentable
      qty = convert(component.quantity, component.unit, ing.unit)
      (qty * BigDecimal(ing.unit_cost_cents.to_s)).to_i
    rescue Recipes::UnitConverter::IncompatibleUnits
      0
    end

    def recipe_component_cents(component)
      child = component.componentable
      child_total = total_cents_for(child)
      return 0 if child_total.zero? || child.yield_quantity.to_d.zero?

      qty_in_yield_unit = convert(component.quantity, component.unit, child.yield_unit)
      ratio = qty_in_yield_unit / BigDecimal(child.yield_quantity.to_s)
      (ratio * BigDecimal(child_total.to_s)).to_i
    rescue Recipes::UnitConverter::IncompatibleUnits
      0
    end

    def convert(quantity, from, to)
      Recipes::UnitConverter.convert(quantity: quantity, from: from, to: to)
    end

    # Writes back only when the value actually changed. Avoids spurious
    # UPDATEs and skips the paper_trail version trail for no-op reads.
    def persist_cache(node, cents)
      target = cents.positive? ? cents : nil
      return if node.cost_cents_cached == target

      node.update_columns(cost_cents_cached: target, updated_at: Time.current)
    end
  end
end
