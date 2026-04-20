module Orders
  # Captures a brand-new pedido. Builds the order + items in a single
  # transaction and snapshots `unit_price_cents` / `unit_cost_cents` from
  # the recipe scoped to the account so the operator can't be tricked into
  # accepting a tampered price posted from the form.
  #
  # On failure, returns the invalid order as `result.object` so the
  # controller can re-render the form with submitted values intact.
  class Place < ApplicationCommand
    option :account
    option :params

    def call
      attrs       = params.to_h.deep_symbolize_keys
      items_attrs = Array(attrs.delete(:items_attributes)&.values || attrs.delete(:items) || [])

      order = account.orders.new(attrs)
      items_attrs.each do |item_attrs|
        next if item_attrs.values_at(:recipe_id, :quantity).all?(&:blank?)

        recipe = account.recipes.kept.saleable.find_by(id: item_attrs[:recipe_id])
        next if recipe.nil?

        order.items.build(
          recipe:           recipe,
          quantity:         (item_attrs[:quantity].presence || 1).to_d,
          unit_price_cents: price_from(item_attrs, recipe),
          unit_cost_cents:  recipe.cost_cents_cached.to_i,
          notes:            item_attrs[:notes].presence
        )
      end

      if order.items.empty?
        order.errors.add(:items, :blank)
        return Result.new(success: false, object: order, errors: order.errors)
      end

      if order.save
        enqueue_geocoding(order)
        success(order)
      else
        Result.new(success: false, object: order, errors: order.errors)
      end
    end

    private

    def enqueue_geocoding(order)
      GeocodeOrderJob.perform_later(order.id) if order.needs_geocoding?
    end

    def price_from(item_attrs, recipe)
      PriceInCents.call(
        submitted: item_attrs[:unit_price] || item_attrs[:unit_price_cents],
        fallback_cents: recipe.sale_price_cents.to_i
      )
    end
  end
end
