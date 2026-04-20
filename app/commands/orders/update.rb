module Orders
  # Updates an existing pedido. New line items get cost+price snapshots
  # from the current recipe state; existing items keep their original
  # unit_cost_cents (snapshot invariant) but accept manual price tweaks.
  class Update < ApplicationCommand
    option :order
    option :params

    def call
      attrs       = params.to_h.deep_symbolize_keys
      items_attrs = attrs.delete(:items_attributes) || {}

      order.assign_attributes(attrs)

      apply_items(items_attrs)

      if order.save
        success(order)
      else
        Result.new(success: false, object: order, errors: order.errors)
      end
    end

    private

    def apply_items(items_attrs)
      items_attrs.each_value do |item_attrs|
        attrs = item_attrs.transform_keys(&:to_sym)

        if attrs[:id].present?
          existing = order.items.find_by(id: attrs[:id])
          next if existing.nil?

          if attrs[:_destroy].to_s.in?(%w[1 true])
            existing.mark_for_destruction
          else
            existing.assign_attributes(
              quantity:         attrs[:quantity].presence || existing.quantity,
              unit_price_cents: price_cents(attrs, existing.unit_price_cents),
              notes:            attrs[:notes]
            )
          end
        else
          next if attrs[:_destroy].to_s.in?(%w[1 true])
          next if attrs.values_at(:recipe_id, :quantity).all?(&:blank?)

          recipe = order.account.recipes.kept.saleable.find_by(id: attrs[:recipe_id])
          next if recipe.nil?

          order.items.build(
            recipe:           recipe,
            quantity:         (attrs[:quantity].presence || 1).to_d,
            unit_price_cents: price_cents(attrs, recipe.sale_price_cents),
            unit_cost_cents:  recipe.cost_cents_cached.to_i,
            notes:            attrs[:notes].presence
          )
        end
      end
    end

    def price_cents(attrs, fallback)
      PriceInCents.call(
        submitted: attrs[:unit_price] || attrs[:unit_price_cents],
        fallback_cents: fallback.to_i
      )
    end
  end
end
