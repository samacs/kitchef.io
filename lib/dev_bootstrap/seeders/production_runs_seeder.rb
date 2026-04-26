module DevBootstrap
  module Seeders
    # Phase 13 — for the two advanced kitchens, flip the inventory toggle
    # on, seed today/yesterday/tomorrow production runs across their
    # saleable recipes, and stamp `last_purchase_quantity` on every
    # ingredient so the low-stock badge has a baseline to compare
    # against. The other six kitchens stay inventory-off so the demo
    # shows both modes side-by-side.
    class ProductionRunsSeeder < Seeder
      def initialize(kitchen_defs, accounts)
        @kitchen_defs = kitchen_defs
        @accounts = accounts
      end

      def call
        @kitchen_defs.each do |kd|
          next unless kd[:mode] == :advanced
          account = @accounts[kd[:key]]
          next if account.nil?

          enable_inventory!(account)
          stamp_baseline_purchase_quantities!(account)
          seed_runs!(account)
        end
      end

      private

      def enable_inventory!(account)
        settings = account.settings
        inv = settings.inventory_settings
        inv.enabled = true
        inv.enabled_at = Time.current
        inv.oversell_policy = "warn"
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
          # Bump current stock so the runs we create below have something
          # to deplete from. Multiplied by 4 to give the demo some slack.
          new_stock = qty_in_canonical * 4
          ing.update_columns(
            stock_quantity:         new_stock,
            stock_updated_at:       Time.current,
            last_purchase_quantity: qty_in_canonical
          )
        end
      end

      def seed_runs!(account)
        recipes = account.recipes.kept.saleable.limit(4)
        return if recipes.empty?

        log "  production runs for #{account.name}"

        # Yesterday — completed
        recipes.first(2).each do |recipe|
          create_run!(account, recipe, Date.current - 1, planned: 8, complete: true)
        end

        # Today — in progress
        recipes.each do |recipe|
          create_run!(account, recipe, Date.current, planned: 6, complete: false)
        end

        # Tomorrow — planned
        recipes.first(2).each do |recipe|
          create_run!(account, recipe, Date.current + 1, planned: 4, complete: false)
        end
      end

      def create_run!(account, recipe, on_date, planned:, complete:)
        result = Production::StartRun.call(
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

        run = result.object
        Production::CompleteRun.call(run: run) if complete && run.aasm.may_fire_event?(:complete)
      end
    end
  end
end
