module Orders
  # Creates a fresh `placed` pedido from an existing (usually canceled)
  # one. Copies the client, items (with their price snapshots re-taken
  # from the recipes' current prices), delivery type/window/address,
  # and internal notes. State lifecycle + cancel reason fields are NOT
  # carried over — the duplicate is a brand-new order that just happens
  # to start from a familiar template.
  #
  # Typical use: Lupita canceled a pedido because she was sick; two
  # days later she wants the same thing. Operator clicks "Duplicar"
  # on the canceled card, the new pedido opens in the drawer for
  # review + re-capture.
  class Duplicate < ApplicationCommand
    option :source
    option :account

    def call
      dup = account.orders.new(attributes_from_source)
      items_from_source.each { |item_attrs| dup.items.build(item_attrs) }

      if dup.save
        success(dup)
      else
        Result.new(success: false, object: dup, errors: dup.errors)
      end
    end

    private

    def attributes_from_source
      {
        client_id:           source.client_id,
        delivery_type:       source.delivery_type,
        source:              :manual,
        delivery_date:       Date.current,
        delivery_start_time: source.delivery_start_time,
        delivery_end_time:   source.delivery_end_time,
        colonia:             source.colonia,
        city:                source.city,
        delivery_address:    source.delivery_address,
        delivery_notes:      source.delivery_notes,
        notes:               source.notes
      }
    end

    def items_from_source
      source.items.map do |item|
        recipe = account.recipes.kept.saleable.find_by(id: item.recipe_id)
        next if recipe.nil?

        {
          recipe:           recipe,
          quantity:         item.quantity,
          # Fresh price snapshot — the source pedido's price may be
          # stale if the recipe's sale price moved since.
          unit_price_cents: recipe.sale_price_cents.to_i,
          unit_cost_cents:  recipe.cost_cents_cached.to_i,
          notes:            item.notes
        }
      end.compact
    end
  end
end
