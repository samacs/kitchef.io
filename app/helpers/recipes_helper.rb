module RecipesHelper
  # Renders the line-cost label for a single recipe component. Reused by
  # the components editor view component AND the re-renderable rows
  # partial that the controller swaps in after autosave.
  def line_cost_label_for(component)
    cents = line_cost_cents_for(component)
    return "—" if cents.nil?

    humanized_money_with_symbol(Money.new(cents, "MXN"))
  end

  def line_cost_cents_for(component)
    target = component.componentable
    return nil if target.nil?

    case target
    when Ingredient
      qty = Recipes::UnitConverter.convert(quantity: component.quantity, from: component.unit, to: target.unit)
      (qty * BigDecimal(target.unit_cost_cents.to_s)).to_i
    when Recipe
      child_cost = target.cost_cents_cached.to_i
      return nil if child_cost.zero? || target.yield_quantity.to_d.zero?

      qty = Recipes::UnitConverter.convert(quantity: component.quantity, from: component.unit, to: target.yield_unit)
      (qty / BigDecimal(target.yield_quantity.to_s) * BigDecimal(child_cost.to_s)).to_i
    end
  rescue Recipes::UnitConverter::IncompatibleUnits
    nil
  end
end
