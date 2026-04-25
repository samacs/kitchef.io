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
      # Hydrate per-pedido packaging from account defaults unless the
      # caller explicitly posted a value. Lets Phase 10 start collecting
      # packaging immediately without every form path needing to know
      # about the setting.
      if order.packaging_cents.to_i.zero? && account.settings.default_packaging_cents.to_i.positive?
        order.packaging_cents = account.settings.default_packaging_cents.to_i
      end

      items_attrs.each do |item_attrs|
        next if item_attrs.values_at(:recipe_id, :quantity).all?(&:blank?)

        recipe = resolve_recipe(item_attrs[:recipe_id])
        next if recipe.nil?

        order.items.build(
          recipe:           recipe,
          quantity:         (item_attrs[:quantity].presence || 1).to_d,
          unit_price_cents: price_from(item_attrs, recipe),
          unit_cost_cents:  recipe.cost_cents_cached.to_i + recipe.packaging_cents.to_i,
          notes:            item_attrs[:notes].presence
        )
      end

      if order.items.empty?
        order.errors.add(:items, :blank)
        return Result.new(success: false, object: order, errors: order.errors)
      end

      if order.save
        # Geocoding enqueue is handled by the Geocodable concern's
        # after_commit callback — no explicit dispatch needed.
        success(order)
      else
        Result.new(success: false, object: order, errors: order.errors)
      end
    end

    private

    # Operator forms post a numeric recipe id; the storefront cart posts
    # the prefixed form (`rec_abc`). Support both so a single command
    # serves every entry point.
    def resolve_recipe(raw_id)
      return nil if raw_id.blank?

      scope = account.recipes.kept.saleable
      if raw_id.to_s.start_with?("rec_")
        scope.find_by_prefix_id(raw_id.to_s)
      else
        scope.find_by(id: raw_id)
      end
    end

    def price_from(item_attrs, recipe)
      PriceInCents.call(
        submitted: item_attrs[:unit_price] || item_attrs[:unit_price_cents],
        fallback_cents: recipe.sale_price_cents.to_i
      )
    end
  end
end
