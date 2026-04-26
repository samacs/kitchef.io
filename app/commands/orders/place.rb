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

        delta_cents = compute_options_delta(item_attrs[:selected_options], recipe)
        quantity    = (item_attrs[:quantity].presence || 1).to_d

        consumed_run, oversold = pick_run_for(recipe, quantity, order)

        order.items.build(
          recipe:                   recipe,
          quantity:                 quantity,
          unit_price_cents:         price_from(item_attrs, recipe) + delta_cents,
          unit_cost_cents:          recipe.cost_cents_cached.to_i + recipe.packaging_cents.to_i,
          notes:                    item_attrs[:notes].presence,
          selected_options:         item_attrs[:selected_options].presence || {},
          removed_components:       Array(item_attrs[:removed_components]),
          options_price_delta_cents: delta_cents,
          consumed_run:             consumed_run,
          consumed_quantity:        consumed_run.present? ? quantity : 0,
          oversold:                 oversold
        )
      end

      if order.items.empty?
        order.errors.add(:items, :blank)
        return Result.new(success: false, object: order, errors: order.errors)
      end

      if account.inventory_enabled? && account.inventory_settings.block_oversells? &&
         order.items.any?(&:oversold?)
        order.errors.add(:items, :out_of_stock)
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

    # Phase 13 — when inventory is enabled, find the oldest active run
    # for this recipe + delivery_date that has enough remaining units.
    # Returns [run, oversold]; both nil/false when inventory is off
    # (the order item proceeds with the legacy untracked behavior).
    def pick_run_for(recipe, quantity, order)
      return [ nil, false ] unless account.inventory_enabled?
      return [ nil, false ] if order.delivery_date.blank?

      run = Orders::RunPicker.call(
        account:       account,
        recipe:        recipe,
        delivery_date: order.delivery_date,
        quantity:      quantity
      )

      if run
        [ run, false ]
      else
        [ nil, true ]
      end
    end

    def compute_options_delta(selected_options, recipe)
      return 0 if selected_options.blank?

      option_ids = selected_options.values.flat_map do |selections|
        Array(selections).filter_map { |s| s[:id] || s["id"] }
      end
      return 0 if option_ids.empty?

      RecipeOption.where(
        id: option_ids,
        recipe_option_group_id: recipe.option_groups.select(:id)
      ).sum(:price_delta_cents)
    end
  end
end
