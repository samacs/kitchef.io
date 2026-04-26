module DevBootstrap
  module Seeders
    class IngredientsSeeder < Seeder
      def initialize(kitchen_defs, accounts)
        @kitchen_defs = kitchen_defs
        @accounts = accounts
      end

      def call
        @kitchen_defs.each do |kd|
          next if kd[:ingredients].blank?

          account = @accounts[kd[:key]]
          log "  ingredients for #{account.name} (#{kd[:ingredients].size})"

          kd[:ingredients].each do |ing|
            cat = account.categories.kept.find_by(kind: :ingredient, name: ing[:cat])
            account.ingredients.create!(
              name:            ing[:name],
              unit:            ing[:unit],
              unit_cost_cents: cents(ing[:cost]),
              category:        cat
            )
          end
        end
      end
    end
  end
end
