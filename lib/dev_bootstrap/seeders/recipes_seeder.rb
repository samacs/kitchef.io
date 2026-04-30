module DevBootstrap
  module Seeders
    class RecipesSeeder < Seeder
      def initialize(kitchen_defs, accounts)
        @kitchen_defs = kitchen_defs
        @accounts = accounts
      end

      def call
        @kitchen_defs.each do |kd|
          account = @accounts[kd[:key]]
          seed_base_recipes(account, kd)
          seed_saleable_recipes(account, kd)
          warm_cost_caches(account, kd) if kd[:mode] == :advanced
        end
      end

      private

      def seed_base_recipes(account, kd)
        return if kd[:base_recipes].blank?
        log "  base recipes for #{account.name} (#{kd[:base_recipes].size})"

        cat = account.categories.kept.find_by(kind: :recipe, name: "Bases y preparaciones")

        kd[:base_recipes].each do |br|
          recipe = account.recipes.create!(
            name:           br[:name],
            is_saleable:    false,
            is_published:   false,
            yield_quantity: br[:yield_qty],
            yield_unit:     br[:yield_unit],
            category:       cat,
            sale_price_cents: 0
          )

          (br[:ingredients] || []).each do |comp|
            ingredient = account.ingredients.find_by(name: comp[:name])
            next unless ingredient
            recipe.components.create!(
              componentable: ingredient,
              quantity:       comp[:qty],
              unit:           ingredient.unit
            )
          end
        end
      end

      def seed_saleable_recipes(account, kd)
        return if kd[:recipes].blank?
        log "  recipes for #{account.name} (#{kd[:recipes].size})"

        kd[:recipes].each do |rd|
          cat = account.categories.kept.find_by(kind: :recipe, name: rd[:cat])
          recipe = account.recipes.create!(
            name:             rd[:name],
            is_saleable:      true,
            is_published:     true,
            sale_price_cents: cents(rd[:price]),
            yield_quantity:   rd[:yield_qty] || 1,
            yield_unit:       rd[:yield_unit] || "piece",
            lead_time_hours:  rd[:lead_time] || 0,
            category:         cat
          )

          if rd[:base].present? && kd[:mode] == :advanced
            base = account.recipes.where(is_saleable: false).find_by(name: rd[:base])
            if base
              recipe.components.create!(componentable: base, quantity: 1, unit: base.yield_unit)
            end
          end

          seed_option_groups(account, recipe, rd[:option_groups]) if rd[:option_groups].present?

          slug = rd[:name].parameterize
          ImageCache.attach(recipe, :photos, slug: slug, unsplash_id: rd[:photo_id])
        end
      end

      def seed_option_groups(account, recipe, groups_defs)
        groups_defs.each do |gd|
          group = recipe.option_groups.create!(
            account:        account,
            label:          gd[:label],
            sub:            gd[:sub],
            kind:           gd[:kind],
            required:       gd[:required] || false,
            selection_mode: :uniform
          )

          (gd[:options] || []).each do |od|
            componentable = resolve_componentable(account, od)
            group.options.create!(
              label:              od[:label],
              is_default:         od[:default] || false,
              price_delta_cents:  cents(od[:delta] || 0),
              componentable:      componentable,
              quantity:           componentable ? od[:qty] : nil,
              unit:               componentable ? od[:unit] : nil
            )
          end
        end
      end

      def resolve_componentable(account, option_def)
        if option_def[:ingredient]
          account.ingredients.find_by(name: option_def[:ingredient])
        elsif option_def[:base]
          account.recipes.where(is_saleable: false).find_by(name: option_def[:base])
        end
      end

      def warm_cost_caches(account, _kd)
        log "  warming cost caches for #{account.name}"
        account.recipes.kept.find_each do |r|
          Recipes::CostCalculator.for(recipe: r)
          Recipes::OptionCostCalculator.call(recipe: r)
        rescue StandardError => e
          warn "    ⚠  cost cache failed for #{r.name}: #{e.message}"
        end
      end
    end
  end
end
