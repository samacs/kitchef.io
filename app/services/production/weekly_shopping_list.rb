module Production
  # Aggregated shopping list for the next 7 days.
  #
  # Simple mode (account.composable_recipes? == false) returns rows
  # grouped by saleable recipe — what Phase 5 shipped.
  #
  # Advanced mode (account.composable_recipes? == true) expands each
  # recipe into its component tree and returns ingredient-granular rows,
  # summing quantities across the week's upcoming confirmed orders. This
  # is the deferred value Phase 5's "cuando decompongas tus recetas esta
  # lista baja al nivel de ingrediente" nudge promised.
  #
  # Only confirmed-or-later orders count — `placed` pedidos are awaiting
  # the operator's decision and would poison the list with speculative
  # purchases.
  class WeeklyShoppingList < ApplicationService
    ShoppingRow = Data.define(:recipe, :recipe_name, :total_qty, :unit, :prep_notes) do
      def display_qty
        WeeklyShoppingList.format_quantity(total_qty)
      end
    end

    IngredientRow = Data.define(:ingredient, :ingredient_name, :category, :total_qty, :unit, :source_recipes) do
      def display_qty
        WeeklyShoppingList.format_quantity(total_qty)
      end
    end

    Result = Data.define(:starting, :ending, :rows, :mode) do
      def empty? = rows.empty?
      def advanced? = mode == :advanced
    end

    QUALIFYING_STATES = %w[confirmed in_production ready en_route delivered].freeze
    WINDOW_DAYS = 7

    option :account
    option :starting, default: -> { Date.current }

    def self.for(account:, starting: Date.current)
      call(account: account, starting: starting)
    end

    def self.format_quantity(qty)
      bd = BigDecimal(qty.to_s)
      # Round to 3 decimal places — enough precision for kitchen scale
      # quantities without the BigDecimal tail BigDecimal division can
      # generate (e.g. 0.53911111...).
      rounded = bd.round(3)
      formatted = rounded.to_s("F").sub(/\.0+\z/, "").sub(/(\.\d*?)0+\z/, '\1')
      formatted.presence || qty.to_s
    end

    def call
      ending = starting + (WINDOW_DAYS - 1).days
      orders = account.orders.kept
        .where(delivery_date: starting..ending)
        .where(state: QUALIFYING_STATES)
        .includes(items: :recipe)

      if account.composable_recipes?
        Result.new(starting: starting, ending: ending, rows: aggregate_ingredients(orders), mode: :advanced)
      else
        Result.new(starting: starting, ending: ending, rows: aggregate_recipes(orders), mode: :simple)
      end
    end

    private

    def aggregate_recipes(orders)
      buckets = Hash.new { |h, k| h[k] = { recipe: nil, total: BigDecimal("0"), notes: [] } }

      orders.each do |order|
        order.items.each do |item|
          next if item.recipe.nil?

          bucket = buckets[item.recipe.id]
          bucket[:recipe] ||= item.recipe
          bucket[:total]  += BigDecimal(item.quantity.to_s)
          bucket[:notes] << item.notes.strip if item.notes.present?
        end
      end

      buckets.values
        .sort_by { |b| [ -b[:total], b[:recipe].name.to_s.downcase ] }
        .map do |b|
          ShoppingRow.new(
            recipe:      b[:recipe],
            recipe_name: b[:recipe].name,
            total_qty:   b[:total],
            unit:        b[:recipe].yield_unit,
            prep_notes:  b[:notes]
          )
        end
    end

    # Ingredient-granular aggregation. For each order item, walk the
    # recipe's component tree, scale each ingredient line by the
    # ordered quantity, and sum into a per-ingredient bucket in the
    # ingredient's canonical unit.
    def aggregate_ingredients(orders)
      buckets = {}

      orders.each do |order|
        order.items.each do |item|
          recipe = item.recipe
          next unless recipe

          qty_factor = BigDecimal(item.quantity.to_s)
          expand_recipe(recipe, qty_factor, buckets, source_recipe: recipe)
        end
      end

      buckets.values
        .sort_by { |b| [ b[:ingredient]&.category&.position || 999, b[:ingredient]&.name.to_s.downcase ] }
        .map do |b|
          IngredientRow.new(
            ingredient:      b[:ingredient],
            ingredient_name: b[:ingredient].name,
            category:        b[:ingredient].category,
            total_qty:       b[:total],
            unit:            b[:ingredient].unit,
            source_recipes:  b[:sources].uniq.compact
          )
        end
    end

    # Recursive expansion. `factor` is how many units of the enclosing
    # recipe we need (1 for the outermost order item; fractional for
    # internal sub-recipes scaled by their yield).
    def expand_recipe(recipe, factor, buckets, source_recipe:)
      recipe.components.includes(:componentable).each do |component|
        case component.componentable
        when Ingredient then accumulate_ingredient(component, factor, buckets, source_recipe: source_recipe)
        when Recipe     then accumulate_recipe(component, factor, buckets, source_recipe: source_recipe)
        end
      end
    end

    def accumulate_ingredient(component, factor, buckets, source_recipe:)
      ing = component.componentable
      qty_in_canonical =
        begin
          Recipes::UnitConverter.convert(quantity: component.quantity, from: component.unit, to: ing.unit)
        rescue Recipes::UnitConverter::IncompatibleUnits
          BigDecimal("0")
        end

      bucket = (buckets[ing.id] ||= { ingredient: ing, total: BigDecimal("0"), sources: [] })
      bucket[:total] += qty_in_canonical * factor
      bucket[:sources] << source_recipe.name
    end

    def accumulate_recipe(component, factor, buckets, source_recipe:)
      child = component.componentable
      return if child.yield_quantity.to_d.zero?

      qty_in_child_yield =
        begin
          Recipes::UnitConverter.convert(quantity: component.quantity, from: component.unit, to: child.yield_unit)
        rescue Recipes::UnitConverter::IncompatibleUnits
          BigDecimal("0")
        end
      scaled_factor = factor * (qty_in_child_yield / BigDecimal(child.yield_quantity.to_s))

      expand_recipe(child, scaled_factor, buckets, source_recipe: source_recipe)
    end
  end
end
