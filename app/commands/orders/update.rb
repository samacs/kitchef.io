module Orders
  # Updates an existing pedido. New line items get cost+price snapshots
  # from the current recipe state; existing items keep their original
  # unit_cost_cents (snapshot invariant) but accept manual price tweaks.
  class Update < ApplicationCommand
    option :order
    option :params

    # Address columns whose change should re-trigger geocoding. If the
    # operator only tweaked the delivery_notes or delivery_date, there's
    # no need to spend a Google quota request.
    GEO_RELEVANT = %w[delivery_address colonia city delivery_type].freeze

    def call
      attrs       = params.to_h.deep_symbolize_keys
      items_attrs = attrs.delete(:items_attributes) || {}

      order.assign_attributes(attrs)
      address_changed = order.changed & GEO_RELEVANT

      apply_items(items_attrs)

      if order.save
        reset_geocoding(order) if address_changed.any?
        enqueue_geocoding(order)
        success(order)
      else
        Result.new(success: false, object: order, errors: order.errors)
      end
    end

    private

    def reset_geocoding(order)
      order.update_columns(
        latitude:            nil,
        longitude:           nil,
        geocoded_at:         nil,
        geocoding_failed_at: nil
      )
    end

    def enqueue_geocoding(order)
      GeocodeOrderJob.perform_later(order.id) if order.needs_geocoding?
    end

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
