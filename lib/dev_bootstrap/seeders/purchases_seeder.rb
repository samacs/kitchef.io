module DevBootstrap
  module Seeders
    class PurchasesSeeder < Seeder
      def initialize(kitchen_defs, accounts)
        @kitchen_defs = kitchen_defs
        @accounts = accounts
      end

      def call
        @kitchen_defs.each do |kd|
          account = @accounts[kd[:key]]
          next if kd[:ingredients].blank? || kd[:suppliers].blank?
          next if kd[:history_days] < 10

          count = kd[:history_days] >= 25 ? 8 : 3
          log "  purchases for #{account.name} (#{count})"

          suppliers   = account.suppliers.to_a
          ingredients = account.ingredients.to_a

          count.times do |i|
            supplier = suppliers.sample
            date = Date.current - rand(1..kd[:history_days])
            items = ingredients.sample(rand(2..5)).map do |ing|
              {
                ingredient_id: ing.id,
                quantity:       [ 1, 2, 3, 5 ].sample,
                unit:           ing.unit,
                unit_cost_cents: (ing.unit_cost_cents * (0.9 + rand * 0.2)).to_i
              }
            end

            Purchases::Create.call(
              account:  account,
              params:   {
                purchased_on: date,
                supplier_id:  supplier.id,
                notes:        i.zero? ? "Compra de mercado semanal" : "",
                items_attributes: items.each_with_index.map { |it, idx| [ idx.to_s, it ] }.to_h
              }
            )
          end
        end
      end
    end
  end
end
