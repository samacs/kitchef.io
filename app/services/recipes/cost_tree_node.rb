module Recipes
  # Immutable node type used by the cost-tree view. Each node carries
  # the display name, quantity + unit, dollar cost, and the set of
  # child nodes (empty for ingredient leaves).
  #
  # Building the tree walks the component list once per recipe and
  # recurses into recipe componentables. Cycles are already forbidden
  # at the model layer, so the traversal can assume a DAG.
  class CostTreeNode
    attr_reader :name, :quantity, :unit, :cost_cents, :children, :kind, :internal, :byproduct

    def initialize(name:, quantity:, unit:, cost_cents:, children:, kind:, internal: false, byproduct: false)
      @name = name
      @quantity = quantity
      @unit = unit
      @cost_cents = cost_cents
      @children = children
      @kind = kind
      @internal = internal
      @byproduct = byproduct
    end

    def byproduct? = byproduct

    def self.build(recipe:)
      total = recipe.cost_cents_cached.to_i
      if total.zero?
        # Cache miss — fall back to a live calculation so the detail
        # page is never stuck rendering "—" on a freshly seeded recipe.
        total = Recipes::CostCalculator.for(recipe: recipe).cents
        recipe.reload
      end

      new(
        name:       recipe.name,
        quantity:   recipe.yield_quantity,
        unit:       recipe.yield_unit,
        cost_cents: total,
        kind:       :recipe,
        internal:   !recipe.is_saleable?,
        children:   recipe.components.includes(:componentable).map { |c| node_for(c) }
      )
    end

    def self.node_for(component)
      case component.componentable
      when Ingredient then node_for_ingredient(component)
      when Recipe     then node_for_recipe(component)
      else
        new(name: "—", quantity: component.quantity, unit: component.unit,
            cost_cents: 0, children: [], kind: :unknown)
      end
    end

    def self.node_for_ingredient(component)
      ing = component.componentable
      qty = begin
        Recipes::UnitConverter.convert(quantity: component.quantity, from: component.unit, to: ing.unit)
      rescue Recipes::UnitConverter::IncompatibleUnits
        BigDecimal("0")
      end
      cents = (qty * BigDecimal(ing.unit_cost_cents.to_s)).to_i

      new(name: ing.name, quantity: component.quantity, unit: component.unit,
          cost_cents: cents, children: [], kind: :ingredient)
    end

    def self.node_for_recipe(component)
      child = component.componentable
      is_byproduct = component.is_byproduct?
      cents = is_byproduct ? 0 : child_cents(component, child)

      new(
        name:       child.name,
        quantity:   component.quantity,
        unit:       component.unit,
        cost_cents: cents,
        kind:       :recipe,
        internal:   !child.is_saleable?,
        byproduct:  is_byproduct,
        children:   child.components.includes(:componentable).map { |c| node_for(c) }
      )
    end

    def self.child_cents(component, child)
      child_total = child.cost_cents_cached.to_i
      return 0 if child_total.zero? || child.yield_quantity.to_d.zero?

      qty = Recipes::UnitConverter.convert(quantity: component.quantity, from: component.unit, to: child.yield_unit)
      ((qty / BigDecimal(child.yield_quantity.to_s)) * BigDecimal(child_total.to_s)).to_i
    rescue Recipes::UnitConverter::IncompatibleUnits
      0
    end

    def money
      Money.new(cost_cents, "MXN")
    end

    def leaf?
      children.empty?
    end

    def quantity_label
      q = BigDecimal(quantity.to_s).to_s("F").sub(/\.0+\z/, "").sub(/(\.\d*?)0+\z/, '\1')
      q.presence || quantity.to_s
    end
  end
end
