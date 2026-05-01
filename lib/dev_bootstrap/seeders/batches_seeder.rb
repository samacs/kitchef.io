module DevBootstrap
  module Seeders
    # Phase 13 — for the two advanced kitchens, flip the inventory
    # toggle on, seed yesterday/today/tomorrow batches across their
    # saleable recipes, and stamp `last_purchase_quantity` on every
    # ingredient so the low-stock badge has a baseline to compare
    # against. The other six kitchens stay inventory-off so the demo
    # shows both modes side-by-side.
    class BatchesSeeder < Seeder
      def initialize(kitchen_defs, accounts)
        @kitchen_defs = kitchen_defs
        @accounts = accounts
      end

      def call
        @kitchen_defs.each do |kd|
          next unless kd[:mode] == :advanced
          account = @accounts[kd[:key]]
          next if account.nil?

          enable_inventory!(account, kd)
          stamp_baseline_purchase_quantities!(account)
          seed_batches!(account)
          seed_oversold_demo_order!(account)
        end
      end

      private

      def enable_inventory!(account, kd)
        settings = account.settings
        inv = settings.inventory_settings
        inv.enabled = true
        inv.enabled_at = Time.current
        inv.oversell_policy = kd[:oversell_policy] || "warn"
        settings.inventory_settings = inv
        account.settings = settings
        account.save!
      end

      # Pre-populate `last_purchase_quantity` from the most recent
      # PurchaseItem for every ingredient. The Phase 9 seeder ran
      # before us, so every ingredient that's been bought has a
      # row in purchase_items to draw from. Without this, low-stock
      # always returns false and the badge never appears in the demo.
      def stamp_baseline_purchase_quantities!(account)
        account.ingredients.kept.find_each do |ing|
          last_item = ing.purchase_items.joins(:purchase).order("purchases.purchased_on desc").first
          next if last_item.nil?

          qty_in_canonical = Recipes::UnitConverter.convert(
            quantity: last_item.quantity,
            from:     last_item.unit,
            to:       ing.unit
          )
          # Bump current stock so the batches we create below have
          # something to deplete from. Multiplied by 4 for demo slack.
          new_stock = qty_in_canonical * 4
          ing.update_columns(
            stock_quantity:         new_stock,
            stock_updated_at:       Time.current,
            last_purchase_quantity: qty_in_canonical
          )
        end
      end

      def seed_batches!(account)
        recipes = account.recipes.kept.saleable.where(made_to_order: false).limit(4)
        return if recipes.empty?

        log "  batches for #{account.name}"

        recipes.first(2).each do |recipe|
          create_batch!(account, recipe, Date.current - 1, planned: 8, complete: true)
        end
        recipes.each do |recipe|
          create_batch!(account, recipe, Date.current, planned: 6, complete: false)
        end
        recipes.first(2).each do |recipe|
          create_batch!(account, recipe, Date.current + 1, planned: 4, complete: false)
        end
      end

      # Place a demo order whose quantity exceeds today's available
      # batches so the kanban surfaces the "sin stock" educational
      # chip + the "Anotar un lote" CTA out of the box. Without this
      # the operator only sees the chip if she happens to oversell
      # while exercising the demo. Picks the recipe least covered by
      # today's batches to maximize the visual.
      def seed_oversold_demo_order!(account)
        client  = account.clients.kept.first
        recipes = account.recipes.kept.saleable.to_a
        return if client.nil? || recipes.empty?

        # Pick a recipe that has NO batch for today, or whose batches
        # we can blow past with a generous quantity. Falls back to the
        # first recipe so the demo always has something.
        target = recipes.find do |r|
          Orders::BatchPicker.available_units(account: account, recipe: r, on_date: Date.current).to_i.zero?
        end || recipes.last
        quantity = [ Orders::BatchPicker.available_units(account: account, recipe: target, on_date: Date.current).to_i + 5, 5 ].max

        Orders::Place.call(
          account: account,
          params: {
            client_id:        client.id,
            delivery_date:    Date.current.to_s,
            delivery_type:    0,
            delivery_address: "Av. Demo 100",
            colonia:          "Centro",
            city:             "Hermosillo",
            items:            [ { recipe_id: target.id, quantity: quantity } ]
          }
        )
      end

      def create_batch!(account, recipe, on_date, planned:, complete:)
        result = Batches::Create.call(
          account: account,
          params: {
            recipe_id:        recipe.id,
            planned_quantity: planned,
            cooked_on:        on_date.to_s,
            available_from:   on_date.to_s,
            available_until:  (on_date + 1).to_s
          }
        )
        return unless result.success?

        batch = result.object
        Batches::Complete.call(batch: batch) if complete && batch.aasm.may_fire_event?(:complete)
      end
    end
  end
end
